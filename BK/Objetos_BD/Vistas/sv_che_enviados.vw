create or replace force view it.sv_che_enviados as
select registro,cod_oficina,fecha,orden
  from
--CABECERA
(
select 'CLRENVIADO'|| 
       lpad(fug_obt_cod_banco,4,'0')||
       to_char(fecha,'yyyymmdd')||
       lpad(to_char(sum(monto)),17,'0')||
       lpad(to_char(count(*)),6,'0') registro,--lpad(to_char(count(*)-2),6,'0') registro, /* para q hacia -2 ?????*/
       cod_oficina,
       fecha,
       'C' orden
  from cc_che_remitidos
group by cod_oficina,fecha
union --DETALLE
select lpad(cod_banco,4,'0')||
       rpad(nro_cuenta,12,' ')||
       rpad(nro_cheque,8,' ')||
       lpad(to_char(monto),17,'0') registro,
       cod_oficina,
       fecha,
       'D' orden
  from cc_che_remitidos
)
order by orden
;

