-- Add/modify columns table temporary
alter table PR_PRE_CHE_ROGA_TMP modify detalle_1 VARCHAR2(1000);
alter table PR_PRE_CHE_ROGA_TMP modify detalle_2 VARCHAR2(1000);
alter table PR_PRE_CHE_ROGA_TMP modify detalle_3 VARCHAR2(1000);
alter table PR_PRE_CHE_ROGA_TMP modify detalle_4 VARCHAR2(1000);
alter table PR_PRE_CHE_ROGA_TMP modify detalle_5 VARCHAR2(1000);

-- Add/modify columns table master
alter table PR_PRE_CHE_ROGA modify detalle_1 VARCHAR2(1000);
alter table PR_PRE_CHE_ROGA modify detalle_2 VARCHAR2(1000);
alter table PR_PRE_CHE_ROGA modify detalle_3 VARCHAR2(1000);
alter table PR_PRE_CHE_ROGA modify detalle_4 VARCHAR2(1000);
alter table PR_PRE_CHE_ROGA modify detalle_5 VARCHAR2(1000);
