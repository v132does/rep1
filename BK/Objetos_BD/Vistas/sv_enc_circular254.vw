create or replace force view it.sv_enc_circular254 as
select
   lpad(to_char(rownum),4,'0')||lpad(trim(v.cod_moneda),4,'0')||
   lpad(trim(v.cod_cuenta),3,'0')||lpad(trim(v.cod_subcuenta),2,'0')||
   lpad(trim(v.plazo),2,'0')||lpad(trim(v.rango),2,'0')||
   lpad(trim(to_char(v.can_cuenta)),9,'0')||
   lpad(replace(replace(trim(to_char(v.importe,'999,999,999,999,999.99')),',',''),'.',''),17,'0')||
   lpad(trim(v.cta_departamento),2,'0')||lpad(trim(v.enc_exonerado),1,'0') archivo
from (
select
   a.cod_moneda,a.cod_cuenta,a.cod_subcuenta,a.plazo,a.rango,sum(a.can_cuenta) can_cuenta,sum(a.importe) importe,
   a.cta_departamento,a.enc_exonerado
  from sb_enc_circular254 a
    where a.fecha =
          (select max(m.fecha) from sb_enc_circular254 m)
   group by a.cod_moneda,a.cod_cuenta,a.cod_subcuenta,a.plazo,a.rango,a.cta_departamento,a.enc_exonerado) v;

