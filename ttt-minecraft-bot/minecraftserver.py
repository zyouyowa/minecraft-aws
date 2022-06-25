from datetime import datetime, timedelta
import discord
from discord.ext import commands, tasks
import boto3
from botocore.exceptions import ClientError

#HACK: エラーメッセージをまとめる

class MinecraftServer(commands.Cog):
    def __init__(self, bot, developper, tokens):
        self.bot = bot
        self.tokens = tokens
        self.ec2 = boto3.client('ec2')
        self.stop_reservation = None
        # default minecraft channel
        self.autostop_msg_dest = None
        self.developper = developper
        self.limit_lowest = 3.0 /60.0
        self.limit_highest = 24
        self.default_limit = 12
        print(self.get_ec2_state())
        self.reserve_check.start()
    
    def get_ec2_state(self):
        try:
            data = self.ec2.describe_instances(Filters=[
                {'Name':'tag-key', 'Values':['Name']}, 
                {'Name':'tag-value', 'Values':['Micra-ec2']}
            ])
            ec2_state = data['Reservations'][0]['Instances'][0]['State']['Name']
        except KeyError:
            ec2_state = ""
        return ec2_state
    
    # ec2インスタンス起動
    def start_server(self, automsg_dest_ch):
        print("[minecraft] start_server", automsg_dest_ch)
        # インスタンスの起動状態を確認
        ec2_state = self.get_ec2_state()
        # 起動中なら何もしない
        if ec2_state == 'running' or ec2_state == 'pending':
            return 'already server started'
        # 起動状態がわからなかったら
        elif ec2_state == '':
            return 'aws error: cannot get ec2 status, please retry start'
        #TODO: インスタンスがない場合を考慮する

        try:
            # コマンド実行
            # TODO: dry run導入してテスト可能にする
            res = self.ec2.start_instances(InstanceIds=[self.tokens["A_INS_ID"]], DryRun=False)
            print(res)
            # 指定されたチャンネルをタイムリミットが来た時の投稿先として保存
            self.autostop_msg_dest = automsg_dest_ch
            return 'minecraft server starting'
        except ClientError as e:
            print(e)
            return 'Client Error Occured' + self.developper
    
    # ec2インスタンス停止
    def stop_server(self):
        print("[minecraft] stop_server")
        # インスタンスの起動状態を確認
        ec2_state = self.get_ec2_state()
        # ec2の状態を取れてない状態
        if ec2_state == '':
            return 'aws error: cannot get ec2 status, please retry start'
        # 起動中じゃなければ何もしない
        elif ec2_state != 'running':
            return 'already server stopped'
        #TODO: インスタンスがない場合を考慮する

        try:
            # コマンド実行
            # TODO: dry run導入してテスト可能にする
            res = self.ec2.stop_instances(InstanceIds=[self.tokens["A_INS_ID"]], DryRun=False)
            print(res)
            # 自動停止予定を削除する
            self.clear_timelimit()
            return 'minecraft server stopping'
        except ClientError as e:
            print(e)
            return 'Client Error Occured' + self.developper

    # 自動停止予定を設定する
    def set_timelimit(self, limit, force=False):
        print("[minecraft] set_timelimit", limit, force)
        ec2_state = self.get_ec2_state()
        if not force:
            if ec2_state == '':
                return 'aws error: cannot get ec2 status, please retry start'
            elif ec2_state != 'running':
                return 'command error: server not running'
            #TODO: インスタンスがない場合を考慮する

            # 自動停止予定を全て削除する
            if limit == 'cancel':
                self.clear_timelimit()
                return 'cancel timelimit'
        
        # 数字に変換する　できなかったらエラー
        try:
            num_limit = float(limit)
        except ValueError:
            return 'command error: limit is not number'
        # limitが大きすぎ、小さすぎたらエラー
        if num_limit < self.limit_lowest or num_limit > self.limit_highest:
            return 'command error: settable range=({:.3f}-{})'.format(self.limit_lowest, self.limit_highest)
        
        # 現在時刻からlimit時間後で停止予約
        dt_now = datetime.now() + timedelta(hours=num_limit)
        self.stop_reservation = dt_now
        return 'set timelimit at ' + dt_now.strftime('%m/%d %H:%M')
    
    # 自動停止予約を全て削除する
    def clear_timelimit(self):
        print("[minecraft] clear_timelimit")
        self.stop_reservation = None

    # 60秒ごとに自動停止予約を評価する
    @tasks.loop(seconds=60)
    async def reserve_check(self):
        await self.bot.wait_until_ready()
        
        # stop_reservationが-1のときは自動停止が設定されてない
        if self.stop_reservation is None:
            return
        
        # 現在時刻を取得
        dt_now = datetime.now()
        print("[minecraft] reserve_check:", dt_now)

        # 10分前に通知
        remain = (self.stop_reservation - dt_now) / timedelta(minutes=1)
        if remain > 9.5 and remain <= 10.5:
            print('[minecraft] prev 10 min: ', remain)
            msg = 'stop server after 10 minites'
            channel = self.bot.get_channel(self.autostop_msg_dest)
            await channel.send(msg)
        # 停止予約時間を過ぎてたら
        elif dt_now >= self.stop_reservation:
            # サーバーを停止
            msg = self.stop_server()
            # サーバーを起動したコマンドが書かれたチャンネルで停止を通知
            channel = self.bot.get_channel(self.autostop_msg_dest)
            self.autostop_msg_dest = None
            await channel.send(msg)

    @commands.command()
    async def minecraft(self, ctx, com, *args):
        """マイクラサーバーマシンを起動/終了/終了予約
        $minecraft (start|stop|timelimit *hour*)"""
        if com == 'start':
            msg = self.start_server(ctx.channel.id)
            if len(args) == 0:
                msg += '\n' + self.set_timelimit(self.default_limit, True)
            elif len(args) == 1:
                msg += '\n' + self.set_timelimit(args[0], True)
            else:
                msg += '\ncommand error: the timelimit command needs 1 argument'
        elif com == 'stop':
            msg = self.stop_server()
        elif com == 'timelimit':
            if len(args) == 1:
                msg = self.set_timelimit(args[0])
                self.autostop_msg_dest = ctx.channel.id
            else:
                msg = 'command error: the timelimit command needs 1 argument'
        await ctx.send(msg)
