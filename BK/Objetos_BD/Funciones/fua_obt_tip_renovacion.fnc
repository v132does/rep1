create or replace function it.fua_obt_tip_renovacion
(p_nro_cuenta  in varchar2, p_adherente in varchar2, p_nro_emision in varchar2, p_nro_bin in varchar2 default null)
return varchar2 is
v_retorno varchar2(1) := '1'; -- 1-Reemplazo, 2-Reembozo, 4-Modificación, 5-Re-Impresión

begin
  --PCCDEEVO-491-Ajustes en Envío de Modificación en Nombre de TD-Bancard -18/07/17 DD--  
   select fug_obt_parcausales(cod_causa,'TIP_ACC_BANCARD')
     into v_retorno
     from ah_tar_debitos
    where nro_cuenta = p_nro_cuenta
      and adherente = p_adherente
      and nro_bin = nvl(p_nro_bin, nro_bin)
      and nro_emision = trim(to_char(to_number(p_nro_emision)-1,'00'));
       
   return v_retorno;
exception
  when no_data_found then
    raise_application_error(-20001,'Causal TIP_ACC_BANCARD no encontrado. Cta: '||p_nro_cuenta);--dydmr-10822
  when too_many_rows then --DYDMR-7114
     raise_application_error(-20002, 'Más de un registro definido. Verificar Cta: '||p_nro_cuenta||'-'||'Adher: '||p_adherente);
  when others then
       --v_retorno := '1'; --DYDMR-7105--27/07/17-- Si no está parametrizada la acción en TIP_ACC_BANCARD que de un error.
     raise_application_error(-20003,'Causal TIP_ACC_BANCARD no definido. '||p_nro_cuenta||' * '||sqlerrm);
     --return v_retorno;
end;
/

