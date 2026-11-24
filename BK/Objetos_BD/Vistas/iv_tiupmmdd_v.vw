create or replace force view it.iv_tiupmmdd_v as
select '0007'||
        rpad(lpad('1',2,'0'),3,' ')||
        rpad('PERSONA JURIDICA',40,' ')||
        '*' cadena
from dual
union
select '0007'||
        rpad(lpad('2',2,'0'),3,' ')||
        rpad('PERSONA FISICA',40,' ')||
        '*' cadena
from dual
union
select '0007'||
        rpad(lpad('3',2,'0'),3,' ')||
        rpad('PERSONA FISICA CASADA',40,' ')||
        '*' cadena
from dual;

