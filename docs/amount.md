---
layout: default
title: Amount Defenition
nav_order: 1
---
### Instead of using a number to define an amount, you can also use one of the following keywords

| Keyword | Amount                           |
|---------|----------------------------------|
| all     |  Complete Balance                |
| half    | Half of Balance                  |
| rand    | A random Amount between 1 and 6  |
| bigrand | A random Amount between 1 and 42 |

## Examples
greenbigfrog#4461 has a balance of 112
- `tip @x#0000 all`: Tips x#0000 112
- `tip @x#0000 half`: Tips x#0000 56
- `tip @x#0000 rand`: Tips x#0000 a randomly chosen amount between 1 and 6
- `tip @x#0000 bigrand`: Tips x#0000 a randomly chosen amount between 1 and 42