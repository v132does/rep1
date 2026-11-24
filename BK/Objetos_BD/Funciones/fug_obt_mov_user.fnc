CREATE OR REPLACE FUNCTION IT.fug_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type,
                                               p_nom_secuencia varchar2 )
      RETURN varchar2 is
      v_nro_sec  number;
      v_can_user number;
      v_nro_user number;
      v_user     ba_usuarios.cod_usuario%type;
    begin
      select count(*)
        into v_can_user
        from ba_cod_referencias
       where dominio = 'USU_MOV_SERVICIO'
         and abreviatura = p_tip_user;
      v_nro_sec  := fue_obt_sig_secuencia(p_nom_secuencia);
      v_nro_user := mod(v_nro_sec, v_can_user);
      v_user     := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO', v_nro_user, p_tip_user);
      return v_user;
    end;
/

