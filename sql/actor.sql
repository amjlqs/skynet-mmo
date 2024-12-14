-- --------------------------------------------------------
-- 主机:                           localhost
-- 服务器版本:                      MySQL 5.7.44
-- 服务器操作系统:                  Linux
-- Redis 版本:                     Redis 7.2.4
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;


-- 导出  表 actor.coin_log 结构
DROP TABLE IF EXISTS `coin_log`;
CREATE TABLE IF NOT EXISTS `coin_log` (
  `id` bigint(20) NOT NULL COMMENT '系统编号',
  `actorid` bigint(20) NOT NULL COMMENT '用户ID',
  `type` int(11) NOT NULL DEFAULT '0' COMMENT '变动类型',
  `before_coin` bigint(20) NOT NULL DEFAULT '0' COMMENT '变动前金额',
  `after_coin` bigint(20) NOT NULL DEFAULT '0' COMMENT '变动后金额',
  `amount` bigint(20) NOT NULL DEFAULT '0' COMMENT '变动数量',
  `game_id` int(11) NOT NULL DEFAULT '0' COMMENT '游戏ID',
  `created_at` bigint(20) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `remark` varchar(100) NOT NULL DEFAULT '' COMMENT '备注',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='余额变动明细';

-- 数据导出被取消选择。


-- 导出  表 actor.login_log 结构
DROP TABLE IF EXISTS `login_log`;
CREATE TABLE IF NOT EXISTS `login_log` (
  `id` bigint(20) NOT NULL COMMENT '系统编号',
  `actorid` bigint(20) NOT NULL COMMENT '用户ID',
  `type` bigint(20) NOT NULL DEFAULT '0' COMMENT '登录方式 1:游客 2:手机验证码登录 3:账号密码登录 10:facebook 11:谷歌 12:apple',
  `platform` varchar(50) NOT NULL DEFAULT '' COMMENT '平台: PC_WEB android iOS H5',
  `app_version` varchar(50) NOT NULL DEFAULT '' COMMENT '主包版本',
  `res_version` varchar(50) NOT NULL DEFAULT '' COMMENT '资源版本',
  `device_id` varchar(50) NOT NULL DEFAULT '' COMMENT '设备ID',
  `device_name` varchar(50) NOT NULL DEFAULT '' COMMENT '设备名称',
  `device_model` varchar(50) NOT NULL DEFAULT '' COMMENT '机型',
  `login_time` bigint(20) NOT NULL DEFAULT '0' COMMENT '登录时间',
  `logout_time` bigint(20) NOT NULL DEFAULT '0' COMMENT '登出时间',
  `duration` bigint(20) NOT NULL DEFAULT '0' COMMENT '在线时长',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='登录日志';

-- 数据导出被取消选择。


-- 导出  表 actor.player 结构
DROP TABLE IF EXISTS `player`;
CREATE TABLE IF NOT EXISTS `player` (
  `actorid` bigint(20) NOT NULL COMMENT '玩家ID',
  `name` varchar(50) NOT NULL DEFAULT '' COMMENT '角色名称',
  `rtime` bigint(20) NOT NULL DEFAULT '0' COMMENT '注册时间',
  `energy` bigint(20) NOT NULL DEFAULT '0' COMMENT '能量',
  `coin` bigint(20) NOT NULL DEFAULT '0' COMMENT '金币',
  `gold` bigint(20) NOT NULL DEFAULT '0' COMMENT '元宝',
  `totalpower` bigint(20) NULL DEFAULT 0 COMMENT '总战斗力',
  `head` varchar(512) NOT NULL DEFAULT '0' COMMENT '头像',
  `chapterid` int(11) NULL DEFAULT 0 COMMENT '章节等级记录',
  `autobattle` int(11) NULL DEFAULT 0 COMMENT '是否开启自动战斗 默认0不开启 1开启',
  `attrs` blob COMMENT '属性列表',
  `equips` blob COMMENT '装备列表',
  `skils` blob COMMENT '技能列表',
  `serverindex` int(11) DEFAULT '0' COMMENT '玩家所在的服务器的编号',
  `onlinetime` bigint(20) NOT NULL DEFAULT '0' COMMENT '上线时间',
  PRIMARY KEY (`actorid`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='玩家基础数据表';

-- 数据导出被取消选择。

-- 导出  表 actor.card 结构
DROP TABLE IF EXISTS `card`;
CREATE TABLE IF NOT EXISTS `card` (
  `actorid` bigint(20) NOT NULL COMMENT '玩家ID',
  `data` blob COMMENT '卡牌列表',
  PRIMARY KEY (`actorid`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='卡牌基础数据表';

-- 数据导出被取消选择。

-- 导出  表 actor.bag 结构
DROP TABLE IF EXISTS `bag`;
CREATE TABLE IF NOT EXISTS `bag` (
  `actorid` bigint(20) NOT NULL COMMENT '玩家ID',
  `data` blob COMMENT '背包列表',
  PRIMARY KEY (`actorid`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='背包基础数据表';

-- 数据导出被取消选择。

-- 导出  表 actor.skill 结构
DROP TABLE IF EXISTS `skill`;
CREATE TABLE IF NOT EXISTS `skill` (
  `actorid` bigint(20) NOT NULL COMMENT '玩家ID',
  `data` blob COMMENT '技能列表',
  PRIMARY KEY (`actorid`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='技能基础数据表';

-- 数据导出被取消选择。

-- 导出  表 actor.mails 结构
DROP TABLE IF EXISTS `mails`;
CREATE TABLE `mails`  (
  `uid` bigint(20) NOT NULL COMMENT '邮件ID',
  `actorid` bigint(20) NOT NULL COMMENT '玩家ID',
  `readstatus` int(11) NULL DEFAULT 0 COMMENT '邮件读取状态',
  `sendtime` int(11) NULL DEFAULT 0 COMMENT '发信的unix时间',
  `head` varchar(128) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT NULL COMMENT '邮件标题',
  `context` varchar(1024) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT NULL COMMENT '邮件内容',
  `award` varchar(1024) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT NULL COMMENT '邮件奖励',
  `energy` bigint(20) NOT NULL DEFAULT '0' COMMENT '能量体力值',
  `coin` bigint(20) NOT NULL DEFAULT '0' COMMENT '金币',
  `gold` bigint(20) NOT NULL DEFAULT '0' COMMENT '元宝',
  `awardstatus` int(11) NULL DEFAULT 0 COMMENT '邮件领奖状态',
  PRIMARY KEY (`uid`) USING BTREE
) ENGINE = MyISAM CHARACTER SET = utf8 COLLATE = utf8_general_ci ROW_FORMAT = Dynamic;

-- 数据导出被取消选择。

-- 导出  表 actor.player_crontab 结构
DROP TABLE IF EXISTS `player_crontab`;
CREATE TABLE IF NOT EXISTS `player_crontab` (
  `actorid` bigint(20) NOT NULL,
  `data` varchar(4096) NOT NULL DEFAULT '',
  PRIMARY KEY (`actorid`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='玩家定时器事件表';

-- 数据导出被取消选择。

-- 导出  表 actor.user 结构
DROP TABLE IF EXISTS `user`;
CREATE TABLE IF NOT EXISTS `user` (
  `actorid` bigint(20) NOT NULL COMMENT '用户ID',
  `account` varchar(256) NOT NULL DEFAULT '' COMMENT '第三方平台openid',
  `mobile` varchar(50) NOT NULL DEFAULT '' COMMENT '手机',
  `email` varchar(50) NOT NULL DEFAULT '' COMMENT '邮箱',
  `password` varchar(50) NOT NULL DEFAULT '' COMMENT '密码',
  `created_at` bigint(20) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `ipstr` varchar(50) NOT NULL DEFAULT '' COMMENT '用户上次登录的ip地址',
  `gmlevel` int(11) NULL DEFAULT 10 COMMENT '玩家的gm等级，普通玩家是0.gm等级越高表示权限越高。1-10级gm',
  `createtime` datetime NULL DEFAULT NULL COMMENT '帐号的创建时间',
  `serverindex` int(11) DEFAULT '0' COMMENT '玩家所在的服务器的编号',
  PRIMARY KEY (`actorid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户';

-- 数据导出被取消选择。


-- 导出  表 actor.user_bind 结构
DROP TABLE IF EXISTS `user_bind`;
CREATE TABLE IF NOT EXISTS `user_bind` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '系统编号',
  `platform` tinyint(4) NOT NULL DEFAULT '0' COMMENT '平台1:guest 2:wx 3:apple 4:fb',
  `actorid` bigint(20) NOT NULL DEFAULT 0 COMMENT '用户ID',
  `unionid` varchar(50) NOT NULL DEFAULT '' COMMENT '微信unionid',
  `openid` varchar(50) NOT NULL DEFAULT '' COMMENT '第三方平台openid',
  `created_at` bigint(20) NOT NULL DEFAULT '0' COMMENT '创建时间',
  `passwd` varchar(256) NOT NULL DEFAULT '' COMMENT '密码',
  `updatetime` bigint(20) NOT NULL DEFAULT '0' COMMENT '更新时间',
  `ip` varchar(50) NOT NULL DEFAULT '' COMMENT 'ip地址',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='第三方账号绑定信息';


-- 导出  过程 actor.sp_init_player 结构
DROP PROCEDURE IF EXISTS `sp_init_player`;
DELIMITER //
CREATE DEFINER=`root`@`%localhost` PROCEDURE `sp_init_player`(IN `p_id` BIGINT,IN `serverid` INTEGER,IN `name` VARCHAR(50)
)
BEGIN
	DECLARE is_new INT DEFAULT 0;
	DECLARE user_id BIGINT DEFAULT 0;
	SELECT `actorid` INTO user_id FROM `player` WHERE `actorid` = p_id LIMIT 1;
	IF FOUND_ROWS() = 0 THEN
		INSERT INTO `player`(`actorid`, `name`, `rtime`,`serverindex`) VALUES(p_id, name, UNIX_TIMESTAMP(NOW()),serverid);
    INSERT INTO `card`(`actorid`) VALUES(p_id);
    INSERT INTO `bag`(`actorid`) VALUES(p_id);
    INSERT INTO `skill`(`actorid`) VALUES(p_id);

		SET is_new = 1;
	END IF;
	
	SELECT `actorid` INTO user_id FROM `player_crontab` WHERE `actorid` = p_id LIMIT 1;
  if FOUND_ROWS() = 0 THEN INSERT INTO `player_crontab`(`actorid`) VALUES(p_id); END IF;
	
	SELECT is_new;
END//
DELIMITER ;

-- ----------------------------
-- Procedure structure for loadmaxactoridseries
-- ----------------------------
DROP PROCEDURE IF EXISTS `loadmaxactoridseries`;
DELIMITER //
CREATE DEFINER=`root`@`%localhost` PROCEDURE `loadmaxactoridseries`(IN `serverid` INTEGER)
BEGIN
  SELECT max(actorid >> 30) as maxid FROM player WHERE serverindex=serverid;
END//
DELIMITER ;

-- ----------------------------
-- Procedure structure for updateuserbind
-- ----------------------------
DROP PROCEDURE IF EXISTS `updateuserbind`;
DELIMITER //
CREATE PROCEDURE `updateuserbind`(IN `nactorid` BIGINT, `openid` varchar(50))
begin
  declare aid bigint;
  
  select actorid into aid from user_bind where actorid=nactorid;
  if aid is null then
     insert into user_bind(actorid,openid) values (nactorid, openid);
  end if;
end//
DELIMITER ;



-- 数据导出被取消选择。
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
