#!/bin/bash
ssh dtb 'pg_dump dogecoin > dogecoin.bak'
scp dtb:dogecoin.bak .
scp dtb:.dogecoin/wallet.dat dogecoin.dat.bak

ssh dtb 'pg_dump electra > electra.bak'
scp dtb:electra.bak .
scp dtb:.Electra/wallet.dat electra.dat.bak
