# Discord Tipbot

The tipbot has been created to allow you to easily transfer your coins to other Discord users. It will help to promote the coin since users can tip, soak and rain each other to teach newcomers how it all works and what the community has to offer. It also creates the potential for future game and trivia bots to run off the new tipbot platform.

Whenever you join a server with the tipbot it will register you automatically. You will have your own 'Discord wallet' which stores your balance and is linked only to your Discord account. It is shared across all servers you visit.

The bot is free to use and only collects a fee when you withdraw coins from the bot. This fee is used to cover the transaction fee of the network. It is currently set to `0.0001 BCC`.

# Commands

- ## Balance
  ![balance command](https://i.imgur.com/jPmOC8V.png)

  Check your own balance! Not much else.

- ## Tip
  ![tip command](https://i.imgur.com/MBn0qek.png)

  **Usage: `;tip @user [amount]`**

  You can send any part of your balance to another user by tipping them.

- ## Soak
  ![soak command](https://i.imgur.com/a5guqQu.png)

  **Usage: `;soak [amount]`**

  You can share some coins between some online users! The users are chosen randomly from the collection of users with their status set to online. The coins are split equally.

- ## Rain
  ![rain command](https://i.imgur.com/qOyuzPT.png)

  **Usage: `;rain [amount]`**

  Rain is similar to soak except it will only give coins to users who have spoken in the channel recently. If nobody has spoken in the channel in the last 10 minutes or so it will not distribute your coins. It splits the coins between all active users.

- ## Lucky
  **Usage: `;lucky [amount]`**

  Lucky is like a mixture of both the tip and rain commands. It will choose one random user who has recently spoken to receive your coins.

- ## Deposit
  ![deposit command](https://i.imgur.com/6ksXPTU.png)

  Use this command to retrieve a deposit address from the bot. You can send your coins to this address to have them credited to your Discord account. **This address can only be used once.**

- ## Withdraw
  **Usage: `;withdraw [address] [amount]`**

  This command allows you to withdraw coins from the bot. You must specify the address to send the coins to and the number you want to send. Remember to leave at least `0.0001 BCC` in your balance to cover the withdrawal fee.

- ## Config
  **Usage: `;config [rain|soak|mention] [on|off]`**

  As a server owner you can disable the rain and soak commands in your server if you don't like the spam. You can also disable the @mentions of users in the soak and rain responses from the bot. All of these default to on.

You can view the full command list with the `;help` command.

# Advanced usage

You can substitute any `[amount]` with one of the following:
  - `all` - This will use your entire balance
  - `half` - Unsurprisingly, this will use half of your balance
  - `rand` - This will use between `1 BCC` and `6 BCC`
  - `bigrand` - This will use between `1 BCC` and `42 BCC`

# FAQ

- ### How long does it take to deposit and withdraw coins?

  The bot currently expects 3 confirmations of each transaction before believing them to be truthful. Therefore it is expected that a normal transaction will take around 6 minutes but please allow up to 15 minutes before contacting support.

- ### Are there any fees for using the bot?

  The bot does not charge any fees for transfering coins between users. It charges a withdrawal fee of `0.0001 BCC` when you withdraw coins from the bot to cover the network fees.

- ### How can I support the developers?

  You can make suggestions to improve the bot in the support server as well as contribute code in the GitHub repo. If you want to contribute financially you can use the `;donate` command. Thank you for using the tipbot!

# Support

You can seek support for using the bot in the [Development Server](https://discord.gg/H52pC6j).
