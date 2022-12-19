---
title: 2022-12-02-cgroup memory drop cache
date: 2022-12-02 15:43:32
tags: 网络, etcd, soft lockup
categories: 问题排查与解决
---

# 服务器环境

- 架构

  海光X86

- 内核版本

  4.19.90-23.15.v2101.ky10.x86_64

<!--more-->

# 问题现象描述

- 网络丢包
- 网卡up/down
- etcd超时
- soft lockup等多发现象



# 问题分析

## 现象分析

系统日志中出现 `soft lockup` （软锁死：当进程占用cpu时间超过2*watchdog_thresh会触发soft lockup）情况。

网卡采取多队列方式，每个网卡队列都有绑定到对应的一个CPU核上，当CPU核触发软锁死状态下，所在网卡队列软中断无法得到相应，从而影响卡网队列的数据收发，导致出现“网络丢包、etcd超时、网卡up/down”现象。

通过查看日志中软锁死的信息，第一个以及大部分软锁死信息由kubelet产生。从kubelet进程堆栈打印信息，进程锁死在读取cgroup下`memory.numa_stat`信息过程中。

尝试在有问题的机器上`cat /sys/fs/cgroup/memory/memory.numa_stat`手动读取cgroup信息，查询命令的执行完成消耗接近20秒，较正常的机器（微秒或毫秒级别）高出个级别，属于异常结果表现。



针对上述现象通过`cat /proc/cgroups`去查看cgroup信息，发现 memory cgroup的数量（几万个）比正常机器（几百个）高出了几万个。

同时通过`cat /sys/fs/cgroup/memory/memory.numa_stat`查看 memory.numa_stat，发现memory cgroup的hierarchical_total数也增加了很多，而实际去统计查看memory cgroup下的目录层级数量却很少。

## 原因分析

1. 导致出现大量memory group，以及cgroup统计数量与查看到的目录层级不一致的原因

   cgroup是通过cgroup/cgroup2伪文件系统来管理的，可以通过删除伪文件系统中的文件目录来删除相应的cgroup。

   统及应用的很多相关操作都会触发创建临时的cgroup节点，如容器创建、k8s任务pod创建、cron定时任务、用户登录等，当删除cgroup的目录后虽然用户态已经看不到它，但在内核中代表cgroup的结构体会一直存在知道所有对它的引用被释放。

   只有当被删除的memory cgroup中的页都被回收，相应的引用被释放，该memory cgroup才会彻底被删除，其时间与系统的回收机制有关，如果当中的一些页被活跃的使用，这些页可能永远不会被回收掉。

   因此会出现cgroup信息与查看到的目录层级不一致的现象。

2. 大量的memory cgroup对象是导致读取cgroup信息耗时变长的原因

   通过分析当前版本的内核源码，numa_stat的查看由memcg_numa_stat_show接口实现。

   ```c
   static int memcg_numa_stat_show(struct seq_file *m, void *v)
   {
   	struct numa_stat {
   		const char *name;
   		unsigned int lru_mask;
   	};
   	static const struct numa_stat stats[] = {
   		{ "total", LRU_ALL },
   		{ "file", LRU_ALL_FILE },
   		{ "anon", LRU_ALL_ANON },
   		{ "unevictable", BIT(LRU_UNEVICTABLE) },
   	};
   	const struct numa_stat *stat;
   	int nid;
   	unsigned long nr;
   	struct mem_cgroup *memcg = mem_cgroup_from_css(seq_css(m));
   	for (stat = stats; stat < stats + ARRAY_SIZE(stats); stat++) {
   		nr = mem_cgroup_nr_lru_pages(memcg, stat->lru_mask);
   		seq_printf(m, "%s=%lu", stat->name, nr);
   		for_each_node_state(nid, N_MEMORY) {
   			nr = mem_cgroup_node_nr_lru_pages(memcg, nid,
   							  stat->lru_mask);
   			seq_printf(m, " N%d=%lu", nid, nr);
   		}
   		seq_putc(m, '\n');
   	}
   	for (stat = stats; stat < stats + ARRAY_SIZE(stats); stat++) {
   		struct mem_cgroup *iter;
   		nr = 0;
   		for_each_mem_cgroup_tree(iter, memcg)
   			nr += mem_cgroup_nr_lru_pages(iter, stat->lru_mask);
   		seq_printf(m, "hierarchical_%s=%lu", stat->name, nr);
   		for_each_node_state(nid, N_MEMORY) {
   			nr = 0;
   			for_each_mem_cgroup_tree(iter, memcg)
   				nr += mem_cgroup_node_nr_lru_pages(
   					iter, nid, stat->lru_mask);
   			seq_printf(m, " N%d=%lu", nid, nr);
   		}
   		seq_putc(m, '\n');
   	}
   	return 0;
   }
   ```

   该接口通过遍历整个cgroup树来获取相关统计信息。当系统上整个cgroup树的层级以及节点增大时，其遍历过程的耗时将随之而递增。

# 问题初步分析总结

1. 在系统内核版本中，获取cgroup下numa_stat会随着cgroup的层级以及节点数量增大而耗时变长
2. 通过合入memcg的优化补丁，能解决获取cgroup下numa_stat随着cgroup的层级以及节点数量增大而耗时变长问题

# 问题解决方案

## 临时解决方案——通过周期清理系统cache

问题出现时，通过`echo 3 > /proc/sys/vm/drop_caches`可以清理残留的cgroup内存页信息，减少memory cgroup数量以及层级数。因此，可采用周期性清理cache的方式规避numa_stat读取耗时过长问题。

```shell
#!/bin/bash
timeout 3s cat /sys/fs/cgroup/memory/memory.numa_stat > /dev/null
if [ $? == 124 ];then
  sync;sync;sync #写入硬盘，防止数据丢失
  sleep 1 #延迟1s
  echo 3 > /proc/sys/vm/drop_caches
  echo "drop cache `date`"
fi
```



## 稳定解决方案——升级内核小版本

统计速度慢问题时linux低版本内核通用问题，较新的linux社区内核已有针对cgroup内存统计的优化补丁。