create or replace procedure it.prg_gen_report_befor(p_filtro varchar2) is
v_param varchar2(1000);
v_moneda varchar2(1000);
v_fec_ini varchar2(1000);
v_fec_fin varchar2(1000);
begin
            
--                     19                               51      60                           90        99
  --l.cod_moneda = 'USD' and l.fecha between to_date('01/07/2011','dd/mm/yyyy') and to_date('31/07/2011','dd/mm/yyyy')
  v_param   := p_filtro;
  v_moneda  := substr(v_param,19,3);
  v_fec_ini := substr(v_param,59,10);
  v_fec_fin := substr(v_param,98,10);
--  insert into ge_operaciones_informe2 (param,fec1,fec2,moneda) values (v_param, v_fec_ini, v_fec_fin, v_moneda);
--  l.COD_MONEDA IN ('USD') and l.FECHA Between to_date('01/07/2011','dd/mm/yyyy') and to_date('30/07/2011','dd/mm/yyyy')
  pr_operaciones_efectivo(v_moneda,to_date(v_fec_ini,'dd/mm/yyyy'), to_date(v_fec_fin,'dd/mm/yyyy'));
   commit;
end;
/

