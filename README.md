# FilePackage
Pack a lot of small files into one file for convenient and fast indexing。

文件打包工具，支持几十万到几千万个小文件打包在一个大文件里面。
主要是提升了检索速度，经过测试，5000万个碎片小文件存在一个包下，按照文件名随机检索10000次，响应时间在ms级。
