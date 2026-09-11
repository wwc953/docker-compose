-- 临时关闭只读，允许写入复制元数据
SET GLOBAL super_read_only = OFF;
SET GLOBAL read_only = OFF;

-- 配置并启动复制
CHANGE MASTER TO
  MASTER_HOST='mysql-master',
  MASTER_PORT=3306,
  MASTER_USER='repl',
  MASTER_PASSWORD='repl123',
  MASTER_AUTO_POSITION=1;

START SLAVE;

-- 重新开启只读
SET GLOBAL super_read_only = ON;