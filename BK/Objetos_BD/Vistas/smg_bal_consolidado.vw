create or replace force view it.smg_bal_consolidado as
select ctabcp, mcta, sum(saldoact) saldoact
from (select substr('0'||a.ctabcp,1,3)||'0'||substr('0'||a.ctabcp,5,2) ctabcp, substr(a.mcta,1,3)||'000' mcta, a.saldoact saldoact
from simgia_armamay a
where a.mcta>0
and a.msuc>0
and a.msubcta>0
and a.ctabcp>0) a
group by a.ctabcp, a.mcta

union

select ctabcp, mcta, sum(saldoact) saldoact
from
(select substr('0'||a.ctabcp,1,3)||'0'||substr('0'||a.ctabcp,5,2) ctabcp, substr(a.mcta,1,3)||'0'||substr(a.mcta,5,2) mcta, a.saldoact saldoact
from simgia_armamay a
where a.mcta>0
and a.msuc>0
and a.msubcta>0
and a.ctabcp>0) b
group by b.ctabcp, b.mcta;

