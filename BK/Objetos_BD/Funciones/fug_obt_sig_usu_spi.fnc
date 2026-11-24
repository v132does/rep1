create or replace function it.fug_obt_sig_usu_SPI return varchar2 is

--DYDMR-22560 Mejora PK usuario SPI--
v_cod_usu_retornar varchar2(10);
v_cod_usu_act_SPI varchar2(10);
v_cod_usu_nue_SPI varchar2(10);
v_can_usu_hab_SPI number;
v_can_usu_uti_SPI number;
v_ord_usuario varchar2(10);
v_orden number;
v_seguir varchar2(1) := 'N';
v_usu_agotado varchar2(1) := 'N';

begin
  v_cod_usu_act_SPI := fug_obt_pardinamico('COD_USU_ACT_SPI');
  v_can_usu_hab_SPI := fug_obt_pardinamico('CAN_USU_HAB_SPI');
  v_can_usu_uti_SPI := fug_obt_pardinamico('CAN_USU_UTI_SPI');
  loop
      v_cod_usu_nue_SPI := substr(v_cod_usu_act_SPI,1,5);
      v_ord_usuario := nvl(substr(v_cod_usu_act_SPI,6),'X');
      if fug_val_es_numerico(v_ord_usuario) = 'S' then
         v_orden := to_number(v_ord_usuario) + 1;
         if v_orden > v_can_usu_hab_SPI then
            v_orden := null;
         end if;
      else
        v_orden := 1;
      end if;
      if v_orden > (v_can_usu_hab_SPI - 1) then
         v_cod_usu_retornar := v_cod_usu_nue_SPI;
      else
         v_cod_usu_retornar := v_cod_usu_nue_SPI||trim(to_char(v_orden));
      end if;
      --Verificar si ya esta utilizado--
      if v_can_usu_uti_SPI >= v_can_usu_hab_SPI then
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

