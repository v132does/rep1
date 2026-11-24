create or replace function it.fup_hab_dat_crc(p_cod_persona in varchar2)
  return varchar2 is
  --Referencia:
  --Valida si es posible para habilitacion de campo CRC en pantalla de Riesgos--
  v_fec_control date := to_date('01/'|| to_char(pag_cal.fu_obt_fec_actual(6), 'mm/yyyy'), 'dd/mm/yyyy');
  v_hab_dat_crc varchar2(1) := 'N';
begin
  --Calcular el primer dia del mes anterior--
  select add_months(to_date('01/' || to_char(pag_cal.fu_obt_fec_actual(6), 'mm/yyyy'), 'dd/mm/yyyy'),  -1)
    into v_fec_control
    from dual;
  --Verificar el dato en la tabla de CRC--
  select decode(nvl(count(*), 0), 0, 'S', 'N')
    into v_hab_dat_crc
    from ge_cli_antecedentes x
   where x.cod_persona = p_cod_persona
     and x.fec_crc >= v_fec_control;
  return v_hab_dat_crc;
exception
 when others then
       raise_application_error(-20000, 'Existen problemas con sus antecedentes de CRC. Favor verificar. Cliente: '||p_cod_persona||'  '||sqlerrm);
end;
/

