create or replace function it.fug_obt_sig_usu_hbank return varchar2 is

--PCCDEEVO-1045 / Mejora PK usuario HBANK--
v_cod_usu_retornar varchar2(10);
v_cod_usu_act_hbank varchar2(10);
v_cod_usu_nue_hbank varchar2(10);
v_can_usu_hab_hbank number;
v_can_usu_uti_hbank number;
v_ord_usuario varchar2(10);
v_orden number;
v_seguir varchar2(1) := 'N';
v_usu_agotado varchar2(1) := 'N';

begin
  v_cod_usu_act_hbank := fug_obt_pardinamico('COD_USU_ACT_HBANK');
  v_can_usu_hab_hbank := fug_obt_pardinamico('CAN_USU_HAB_HBANK');
  v_can_usu_uti_hbank := fug_obt_pardinamico('CAN_USU_UTI_HBANK');
  loop
      v_cod_usu_nue_hbank := substr(v_cod_usu_act_hbank,1,5);
      v_ord_usuario := nvl(substr(v_cod_usu_act_hbank,6),'X');
      if fug_val_es_numerico(v_ord_usuario) = 'S' then
         v_orden := to_number(v_ord_usuario) + 1;
         if v_orden > v_can_usu_hab_hbank then
            v_orden := null;
         end if;
      else
        v_orden := 1;
      end if;
      if v_orden > (v_can_usu_hab_hbank - 1) then
         v_cod_usu_retornar := v_cod_usu_nue_hbank;
      else
         v_cod_usu_retornar := v_cod_usu_nue_hbank||trim(to_char(v_orden));
      end if;
      --Verificar si ya esta utilizado--
      if v_can_usu_uti_hbank >= v_can_usu_hab_hbank then
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

