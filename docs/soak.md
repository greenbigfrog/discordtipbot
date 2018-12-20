---
layout: default
title: Soak
nav_order: 1
---
## Soaks transfers crypto to all users who are online in the server
```
soak [amount]
```

### Examples
100 users are online
- `soak 100`: each user receives 1
- `soak 2000`: each user receives 20
- `soak 10`: Only 10 users receive each 1, since there's a a min_soak of 1 set up in the server