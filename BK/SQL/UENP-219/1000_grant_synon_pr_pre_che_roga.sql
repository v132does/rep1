--
create or replace public synonym pr_pre_che_roga for it.pr_pre_che_roga;
grant select, insert, update, delete on it.pr_pre_che_roga to it_temporal;


create or replace public synonym pr_pre_che_roga_tmp for it.pr_pre_che_roga_tmp;
grant select, insert, update, delete on it.pr_pre_che_roga_tmp to it_temporal;