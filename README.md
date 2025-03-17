# Verilog功能模块--I2C主机

## 一. 介绍
本模块实现了几乎全功能的Verilog的I2C主机，可应用于同任意速率，任意地址宽度的I2C从机设备进行通信。

此主机模块还支持页读/页写、从机时钟拉伸、软复位并兼容SCCB协议，但模块未实现时钟同步于仲裁，故不支持多主机。

## 二. 模块功能

本Verilog功能模块实现了I2C主机的功能，具体功能如下：

1. 仅支持7位设备地址（目前市面上还没有10位设备地址的I2C器件，未来可能也不会有）
2. 支持8/16/17/18位数据地址
3. 支持页读/页写
4. 支持从机时钟拉伸
5. 支持从机软复位
6. 支持实时更改I2C总线时钟频率（100kHz、400kHz、1MHz等任意频率可实时更改）
7. 兼容SCCB协议
8. 不支持多主机，即不支持时钟同步和仲裁（99%的情况I2C总线上只会有一个主机）

## 三. 模块框图
<img src="https://picgo-dakang.oss-cn-hangzhou.aliyuncs.com/img/I2C%E6%80%BB%E7%BA%BF%E8%A7%84%E8%8C%83%E8%AF%A6%E8%A7%A3%E5%8F%8A%E5%85%B6Verilog%E5%AE%9E%E7%8E%B004%E2%80%94%E2%80%94I2C%E4%B8%BB%E6%9C%BAVerilog%E5%8A%9F%E8%83%BD%E6%A8%A1%E5%9D%97-1.svg" />

## 四. 更多参考

[I2C总线规范详解及其Verilog实现04——I2C主机Verilog功能模块 – 徐晓康的博客](https://www.myhardware.top/i2c总线规范详解及其verilog实现04-i2c主机verilog功能模块/)

## 其它平台

微信公众号：`徐晓康的博客`

<img src="https://picgo-dakang.oss-cn-hangzhou.aliyuncs.com/img/%E5%BE%90%E6%99%93%E5%BA%B7%E7%9A%84%E5%8D%9A%E5%AE%A2%E5%85%AC%E4%BC%97%E5%8F%B7%E4%BA%8C%E7%BB%B4%E7%A0%81.jpg" alt="徐晓康的博客公众号二维码" />
