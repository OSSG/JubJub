drop table if exists jubjub_messages;
drop table if exists jubjub_errors;
drop table if exists jubjub_participants;
drop table if exists jubjub_jids;
drop table if exists jubjub_resources;
drop table if exists jubjub_jid_types;
drop table if exists jubjub_message_types;

create table jubjub_jid_types (
    `id` tinyint unsigned not null auto_increment primary key,
    `name` varchar(31) not null default ''
) engine=InnoDB;

insert into jubjub_jid_types (name) values ('user');
insert into jubjub_jid_types (name) values ('room');

create table jubjub_jids (
    `id` integer unsigned not null auto_increment primary key,
    `jid` varchar(255) not null default '',
    `log_messages` tinyint unsigned not null default 1,
    `jid_type` tinyint unsigned not null,

    foreign key(jid_type) references jubjub_jid_types(id) on delete cascade on update cascade
) engine=InnoDB;

create table jubjub_resources (
    `id` integer unsigned not null auto_increment primary key,
    `resource` varchar(255)
) engine=InnoDB;

create table jubjub_participants (
    `id` integer unsigned not null auto_increment primary key,
    `jid` integer unsigned not null,
    `resource` integer unsigned not null,

    foreign key(jid) references jubjub_jids(id) on delete cascade on update cascade,
    foreign key(resource) references jubjub_resources(id) on delete cascade on update cascade
) engine=InnoDB;

create table jubjub_message_types (
    `id` tinyint unsigned not null auto_increment primary key,
    `name` varchar(15) not null default ''
) engine=InnoDB;

-- 1 --
insert into jubjub_message_types (name) values ('normal');
-- 2 --
insert into jubjub_message_types (name) values ('chat');
-- 3 --
insert into jubjub_message_types (name) values ('groupchat');
-- 4 --
insert into jubjub_message_types (name) values ('error');
-- 5 --
insert into jubjub_message_types (name) values ('headline');

create table jubjub_errors (
    `id` smallint unsigned not null auto_increment primary key,
    `code` smallint unsigned not null default 0,
    `error_condition` varchar(255) not null default ''
) engine=InnoDB;

create table jubjub_messages (
    `id` integer unsigned not null auto_increment primary key,
    `sender` integer unsigned not null,
    `rcpt` integer unsigned not null,
    `message_id` varchar(255) not null default '',
    `message_time` timestamp default 0,
    `subject` varchar(255) not null default '',
    `body` text not null default '',
    `message_type` tinyint unsigned not null default 1,
    `thread` varchar(255) not null default '',
    `error` smallint unsigned default null,

    foreign key(sender) references jubjub_participants(id) on delete cascade on update cascade,
    foreign key(rcpt) references jubjub_participants(id) on delete cascade on update cascade,
    foreign key(message_type) references jubjub_message_types(id) on delete cascade on update cascade,
    foreign key(error) references jubjub_errors(id) on delete cascade on update cascade
) engine=InnoDB;
