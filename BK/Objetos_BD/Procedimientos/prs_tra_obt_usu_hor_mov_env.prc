create or replace procedure it.prs_tra_obt_usu_hor_mov_env(p_usuario   in varchar2,
                                                           p_usu_mov    out varchar2,
                                                           p_hor_mov    out varchar2)  is
v_tip_oper            varchar2(10):='ENV';
v_tip_transferencia   ba_cod_referencias.val_maximo%type;
v_val_minimo          ge_par_dinamicos.val_parametro%type;
v_val_maximo          ge_par_dinamicos.val_parametro%type;
v_par_min             ge_parametros.parametro%type;
v_par_max             ge_parametros.parametro%type;
v_can_registro        number(5):=0;
v_secuencia           varchar2(100);
v_valor               ba_cod_referencias.val_maximo%type;

begin

       v_tip_transferencia:=FUE_OBT_VAL_MAX_REFERENCIA('SNP_SPI_USUARIOS',p_usuario);
       --se obtiene el nombre de los parametros de la cant. minima y maxima
      v_par_min:= v_tip_transferencia||'_CAN_MIN_USU_'||v_tip_oper;
      v_par_max:= v_tip_transferencia||'_CAN_MAX_USU_'||v_tip_oper;
      --se obtiene el valor minimo y maximo para la generacion de usuarios y secuencias
      v_val_minimo:=nvl(fug_obt_pardinamico(v_par_min),1);
      v_val_maximo:=nvl(fug_obt_pardinamico(v_par_max),5);

      ---se obtiene el usuario
      p_usu_mov:=v_tip_transferencia||round(dbms_random.value(v_val_minimo,v_val_maximo));
      --se valida si el usuario esta registrado en ba_usuarios
      select count(*)
      into v_can_registro
      from ba_usuarios us
      where us.cod_usuario=p_usu_mov;

      if v_can_registro=0 then
          p_usu_mov:=p_usuario;
          p_hor_mov:=to_char(sysdate,'HH24:MI:SS');
         return;
      end if;
      --se obtiene la secuencia para generar la hora del movimiento
       v_secuencia:='S_HOR_MOV_'||v_tip_transferencia||'_'||p_usu_mov;
      --se obtiene la hora en base a la secuencia
      p_hor_mov:=fuw_obt_mov_hora(v_secuencia);
exception
     when others then
         p_usu_mov:=p_usuario;
         p_hor_mov:=to_char(sysdate,'HH24:MI:SS');
end;
/
