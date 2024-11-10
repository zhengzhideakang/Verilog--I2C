# Verilog功能模块--I2C主机

## 介绍
本模块实现了几乎全功能的Verilog的I2C主机，可应用于同任意速率，任意地址宽度的I2C从机设备进行通信。

此主机模块还支持页读/页写、从机时钟拉伸、软复位并兼容SCCB协议，但模块未实现时钟同步于仲裁，故不支持多主机。

## 模块框图
<img src="https://picgo-dakang.oss-cn-hangzhou.aliyuncs.com/img/I2C%E6%80%BB%E7%BA%BF%E8%A7%84%E8%8C%83%E8%AF%A6%E8%A7%A3%E5%8F%8A%E5%85%B6Verilog%E5%AE%9E%E7%8E%B004%E2%80%94%E2%80%94I2C%E4%B8%BB%E6%9C%BAVerilog%E5%8A%9F%E8%83%BD%E6%A8%A1%E5%9D%97-1.svg" />

## 更多参考

[I2C总线规范详解及其Verilog实现04——I2C主机Verilog功能模块 – 徐晓康的博客](https://www.myhardware.top/i2c总线规范详解及其verilog实现04-i2c主机verilog功能模块/)

