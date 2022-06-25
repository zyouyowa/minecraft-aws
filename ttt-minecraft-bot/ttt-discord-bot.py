#!/usr/bin/python3
import os
import json
import random
import discord
from discord.ext import commands, tasks

import minecraftserver

# HACK: トークンファイルを実行時に指定可能にする
with open('/home/ubuntu/ttt-minecraft-bot/tokens.json') as token_file:
    tokens = json.load(token_file)

# Discord Bot
description = "Minecraft Server Control"
bot = commands.Bot(command_prefix='$', description=description)

@bot.event
async def on_ready():
    print('Logged in as user:', bot.user.name, ', id:', bot.user.id)

@bot.command()
async def machitan(ctx):
    """えい、えい、むん！"""
    i = 0
    arr = []
    while True:
        arr.append('えい、' if random.randrange(2) == 0 else 'むん！')
        if len(arr) > 2 and arr[i-2] == 'えい、' and arr[i-1] == 'えい、' and arr[i] == 'むん！':
            break
        i += 1
    await ctx.send(''.join(arr))

bot.add_cog(minecraftserver.MinecraftServer(
    bot, 
    # 鯖を立ててる人のDiscordのIDを指定する
    tokens["D_DEV_ID"], 
    tokens
))

bot.run(tokens["D_TOKEN"])