ext3_metadata_size <- function(file_size)
{
    block_size = 4096;
    #size of the four parts
    mapsizes = c(12*block_size, #direct block
                 (block_size/4)*block_size, #indirect block
                 ((block_size/4)^2)*block_size, #double indirect block
                 ((block_size/4)^3)*block_size
                );
#    print(format(mapsizes, digits=16));

    rem_sz = file_size;
    meta_sz = 128; #inode size
    for (i in 1:4) {
#        print(paste("i:", i, "rem_sz:", rem_sz))
        partsz = mapsizes[i]
        if ( rem_sz <= partsz ) {
#            print("rem_sz<=partsz");
            #file end falls in here
            if ( i == 1 ) {
                break;
            } else {
                nblocks = rem_sz/block_size;
                nblocks_per_ind_block = block_size/4;

                pre_n_ind_blocks = 0
                for ( j in 1:(i-1) ) {
                    cur_n_ind_blocks = 0
                    if ( j == 1 ) {
                        # get number of indirect blocks
                        cur_n_ind_blocks = ceiling(nblocks/nblocks_per_ind_block);
                    } else {
                        cur_n_ind_blocks = ceiling(pre_n_ind_blocks/nblocks_per_ind_block);
                    }
                    meta_sz = meta_sz + cur_n_ind_blocks*block_size
                    pre_n_ind_blocks = cur_n_ind_blocks;
#                    print(paste("cur_n_ind_blocks:", cur_n_ind_blocks))
                }
            }

            break;
        } else {
#            print("rem_sz>partsz");
            if ( i == 4 ) {
                stop("file size is too large");
            } else if ( i %in% c(2,3) ) {
                nblocks = partsz/block_size;
                nblocks_per_ind_block = block_size/4;

                for ( j in 1:(i-1) ) {
                    meta_sz = meta_sz + block_size*(nblocks/(nblocks_per_ind_block^j))
                }
            }
            rem_sz = rem_sz - partsz
        }
    }
    meta_sz
}

plfs_on_ext3 <- function(size_per_proc, nwrites_per_proc, np) 
{
    plfs_index = 48*nwrites_per_proc*np;
    ext_meta_indexfile = ext3_metadata_size(48*nwrites_per_proc)*np
    ext_meta_datafile = ext3_metadata_size(size_per_proc)*np
    return ( data.frame(plfs_index, ext_meta_indexfile, ext_meta_datafile) )
}

ddply_plfs_on_ext3 <- function(df)
{
    tmp = plfs_on_ext3(df$size_per_proc, df$nwrites_per_proc, df$np);
    return(cbind(df, tmp))
}

plot_plfs_on_ext3 <- function()
{
    myseq = c()
    for ( i in 1:3 ) {
        myseq = c(myseq, 4^i);
    }
    df = expand.grid(size_per_proc=myseq*(1024*1024), 
                     nwrites_per_proc=myseq*16, 
                     np=myseq^2);

#print(df);
    df = ddply(df, .(size_per_proc, nwrites_per_proc, np),
            ddply_plfs_on_ext3);
    df$size_per_proc_MB = factor(df$size_per_proc/(1024*1024));
    print(head(df))
#p = ggplot(df, aes(x=np, y=nwrites_per_proc)) +
#            geom_point(aes(size=plfs_index)) +
#            facet_wrap(~factor(size_per_proc))
#    print(p);
    df.melt = melt(df, id=c("size_per_proc_MB", "nwrites_per_proc", "np"), 
                       measure=c("plfs_index", "ext_meta_indexfile", "ext_meta_datafile" ));
    df.melt$value=df.melt$value/(1024*1024);

    nw_order = paste("# of writes per proc:",sort(unique(df.melt$nwrites_per_proc)));
    df.melt$nwrites_per_proc = paste("# of writes per proc:", df.melt$nwrites_per_proc);
    df.melt$nwrites_per_proc = factor(df.melt$nwrites_per_proc, levels = nw_order);

    szproc_order = paste("size_per_proc_MB:", sort(unique(df.melt$size_per_proc_MB)));
    df.melt$size_per_proc_MB = paste("size_per_proc_MB:", df.melt$size_per_proc_MB);
    df.melt$size_per_proc_MB = factor(df.melt$size_per_proc_MB, levels=szproc_order);

    df.melt$text_ypos = 0;
    myadjust = 100
    df.melt$text_ypos[ df.melt$variable == "plfs_index" ] = 350+myadjust;
    df.melt$text_ypos[ df.melt$variable == "ext_meta_indexfile" ] = 400+myadjust;
    df.melt$text_ypos[ df.melt$variable == "ext_meta_datafile" ] = 450+myadjust;

    df.melt$sztext = format(df.melt$value, digit=4, scientific=F);
    print(df.melt)
    pp = ggplot(df.melt, aes(x=factor(np), y=value)) +
            geom_bar(aes(fill=variable), stat="identity", dodge="stack") +
            geom_text(aes(label=sztext, y=text_ypos, color=variable), size=3) +
            facet_grid(nwrites_per_proc~size_per_proc_MB) + 
            xlab("Num of Proc") + ylab("Size (MB)")
    print(pp)
    
}

# this function calcuates the most compact inode size for a file
# each extent node holds 340 index/leaf, each leaf holds 128MB
# this should be the case for PLFS, since PLFS always appending
ext4_metadata_size_v1 <- function(nwrites, wsize, doMerge=T)
{
    EXTENT_SIZE = 128*1024*1024

    if ( doMerge == TRUE ) {
        file_size = nwrites * wsize
        nExtents = ceiling(file_size / EXTENT_SIZE)
    } else {
        n_extent_per_write = ceiling(wsize / EXTENT_SIZE)
        nExtents = nwrites * n_extent_per_write
    }

    INODE_BASE = 256 # inode basic data structure size
    N_EXTENTS_PER_NODE = 340
    N_EXTENTS_L1 = 4*N_EXTENTS_PER_NODE
    N_EXTENTS_L2 = N_EXTENTS_L1 * N_EXTENTS_PER_NODE 
    BLOCKSIZE = 4096

    n_leaves = 0
    n_internals = 0
    if ( nExtents <= 4 ) {
        # do nothing
    } else if ( nExtents <= N_EXTENTS_L1 ) {
        n_leaves = ceiling(nExtents / N_EXTENTS_PER_NODE)
    } else if ( nExtents <= N_EXTENTS_L2 ) {
        n_leaves = ceiling(nExtents / N_EXTENTS_PER_NODE)
        n_internals = ceiling(n_leaves / N_EXTENTS_PER_NODE) 
    } else {
        stop("Extent map overflow")
    }

    total_sz = INODE_BASE + (n_leaves + n_internals) * BLOCKSIZE
    return (total_sz)
}


#####################################################
#####################################################
#####################################################
#####################################################
# HDFS

# This function only calcuate the HDFS part of metadata
# it does not include the underlying ext metadata
hdfs_metadata_size <- function(file_size)
{
    block_size = 64*1024*1024 #64 MB

    nblocks = ceiling(file_size/block_size)    

    # File basic cost
    inode_base = 152
    dir_entry = 64 #TODO: may not need this when we have 
                   # another part calculating dir cost
    filename_len = 13
    filename_sz = filename_len*2
    ref_FSDirectory = 8

    per_file_basic_cost = inode_base + dir_entry + filename_sz + ref_FSDirectory

    # Block cost
    n_replica = 3 # 3 replicas
    blockclass_sz = 32
    blockinfo_sz = 64 + 8*n_replica
    ref_inodeblocks = 8
    BlocksMap_entry = 48
    DatanodeDesc = 64 * n_replica

    per_block_cost = blockclass_sz + blockinfo_sz + ref_inodeblocks + 
                    BlocksMap_entry + DatanodeDesc 

    # Total cost
    total_sz = per_file_basic_cost + nblocks * per_block_cost
    return (c(total_sz, per_file_basic_cost, per_block_cost))
}


hdfs_metadata_size_v2 <- function(file_size)
{
    block_size = 64*1024*1024 #64 MB

    nblocks = ceiling(file_size/block_size)    

    # INodeFile cost for this file
    filename_len = 13
    INodeFile_size = 16 + 
                     24 + filename_len + # name
                     8 + 8 + 8 + 8 +
                     8 + 2 + 8 + 8 +
                     24 + nblocks * 8 # blocks

    # cost of parent dir
    INodeDirectory_parent = 8 # an entry in children

    # cost of BlockInfo for blocks of this file
    n_replica = 3
    per_BlockInfo_size = 16 +
                     8 +
                     8 +
                     24 + 8*n_replica

    total_blockinfo_size = nblocks * per_BlockInfo_size

    # cost of Block
    per_Block_size = 16 + 
                     8 + 8 + 8
    total_Block_sz = nblocks * per_BlockInfo_size

    # cost of BlocksMap
    BlocksMap_size = 48*nblocks # GSet entries. Size not confirmed.

    # cost of DatanodeDescriptor
    DatanodeDescriptor_size = (8 + #reference in BlockQueue
                               16 + 8 + 24+8*n_replica) * nblocks #BlockTargetPair * nblocks

    total_sz = INodeFile_size + INodeDirectory_parent +
                total_blockinfo_size + total_Block_sz +
                BlocksMap_size + DatanodeDescriptor_size

    return (total_sz)
}

hdfs_metadata_size_v3 <- function(file_size)
{
    block_size = 64*1024*1024 #64 MB

    nblocks = ceiling(file_size/block_size)    

    filename_len = 13
    n_replica = 3

    inode_sz = 112+filename_len
    block_sz = 112+24*n_replica

    total_sz = inode_sz + nblocks*block_sz
    return (total_sz)
}


