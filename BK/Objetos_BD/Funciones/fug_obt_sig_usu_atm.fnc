create or replace function it.fug_obt_sig_usu_atm return varchar2 is

v_cod_usu_retornar varchar2(10);
v_cod_usu_atm_actual varchar2(10);
v_cod_usu_atm_nuevo varchar2(10);
v_can_usu_atm_habilitado number;
v_can_usu_atm_utilizado number;
v_ord_usuario varchar2(10);
v_orden number;
v_seguir varchar2(1) := 'N';
v_usu_agotado varchar2(1) := 'N';

begin
  v_cod_usu_atm_actual := fug_obt_pardinamico('COD_USU_ATM_ACTUAL');
  v_can_usu_atm_habilitado := fug_obt_pardinamico('CAN_USU_ATM_HABILITADO');
  v_can_usu_atm_utilizado := fug_obt_pardinamico('CAN_USU_ATM_UTILIZADO');
  loop     
      v_cod_usu_atm_nuevo := substr(v_cod_usu_atm_actual,1,3);
      v_ord_usuario := nvl(substr(v_cod_usu_atm_actual,4),'X');
      if fug_val_es_numerico(v_ord_usuario) = 'S' then
         v_orden := to_number(v_ord_usuario) + 1;
         if v_orden > v_can_usu_atm_habilitado then
            v_orden := null;
         end if;
      else
        v_orden := 1;
      end if;
      if v_orden > (v_can_usu_atm_habilitado - 1) then
         v_cod_usu_retornar := v_cod_usu_atm_nuevo;
      else
         v_cod_usu_retornar := v_cod_usu_atm_nuevo||trim(to_char(v_orden));
      end if;
      --Verificar si ya esta utilizado--
      if v_can_usu_atm_utilizado >= v_can_usu_atm_habilitado then
         v_seguir := 'N';
         v_usu_agotado := 'S';
      else
         v_seguir := 'N';
      end if;
      exit when v_seguir = 'N';
  end loop;
  if v_usu_agotado = 'S' then
     v_cod_usu_retornar := null;
  end if;
  return v_cod_usu_retornar;
end;
/

