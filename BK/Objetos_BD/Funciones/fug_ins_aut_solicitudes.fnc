CREATE OR REPLACE FUNCTION IT.fug_ins_aut_solicitudes
 (P_COD_MODULO IN VARCHAR2, P_COD_MODALIDAD IN VARCHAR2, P_COD_PERSONA IN VARCHAR2, P_TIP_SOLICITUD IN VARCHAR2 )
 RETURN VARCHAR2
 IS
  v_msj varchar2(1000) := '';
  v_nro_pedido ge_aut_solicitudes.nro_pedido%type;
  v_cod_circuito wf_tip_circuitos.cod_tip_circuito%type;
  v_cod_error number;
  PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
begin
  begin
    begin
      select S_NRO_PED_AUT_SOL.nextval
        into v_nro_pedido
        from dual;
    exception
      when others then
        raise_application_error(-20000, 'No se puede obtener el número de secuencia. '||sqlerrm);
    end;
    
    insert into ge_aut_solicitudes (nro_pedido, 
                                    fecha, 
                                    hora, 
                                    cod_usuario,
                                    cod_modulo, 
                                    cod_modalidad, 
                                    cod_persona, 
                                    estado)
	                          values (v_nro_pedido, 
                                    trunc(sysdate), 
                                    to_char(sysdate,'HH24:MI:SS'), 
                                    user, 
                                    p_cod_modulo,
                                    p_cod_modalidad, 
                                    p_cod_persona, 
                                    p_tip_solicitud);

  exception
    when others then
      v_msj := 'No se puede insertar en la tabla PR_AUT_SOLICITUDES. '|| sqlerrm;
      return v_msj;
  end;
  IF p_tip_solicitud = 'S' THEN
     v_cod_circuito := 30;
  ELSIF p_tip_solicitud = 'M' THEN
     v_cod_circuito := 6;
  END IF;		  	    
  v_cod_error := paw_cir.fu_ini_circuito(v_cod_circuito, v_nro_pedido, p_cod_persona);
	if v_cod_error <> 0 then
		 v_msj := 'Al Generar WorkFlow. Error '||v_cod_error;
     return v_msj;
  end if;

  if v_msj is null then
     v_msj := 'OK';
     commit;
     return v_msj;
  end if;
       
end;
/

