create or replace force view it.sv_dat_financieros as
select f.cod_informe || ';' || round(f.valor,0) linea, f.cod_informe registro, f.fecha
  from SB_DAT_FINANCIEROS f
order by fecha, cod_informe;

