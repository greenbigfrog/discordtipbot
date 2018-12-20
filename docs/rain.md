---
layout: default
title: Rain
nav_order: 1
---
## Rain transfers crypto to all users that sent a message in the channel in the past 10 minutes

```
rain [amount]
```

### Examples
5 Users sent a message in the past 10 minutes.
- `rain 10`: each user receives 2
- `rain 1010`: each user receives 202
- `rain 1`: only one user receives 1, since there's a `min_rain` of 1 setup in the server
