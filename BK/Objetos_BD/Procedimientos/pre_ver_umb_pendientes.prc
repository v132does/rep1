create or replace procedure it.pre_ver_umb_pendientes (P_COD_USUARIO   in BA_USUARIOS.COD_USUARIO%TYPE,
                                                       P_MENSAJE       in out VARCHAR2,
                                                       P_COD_PROGRAMA  in out BA_PROGRAMAS.COD_PROGRAMA%TYPE) is
  v_cant_pend     number := 0;
  v_tiene_acceso  number := 0;
  v_cta_empleado  varchar2(1);
begin
  p_cod_programa := null;
  p_mensaje      := null;

  -- 1. Validar si el usuario tiene acceso operativo a GMCONUMB (Cumplimiento)
  select count(1)
    into v_tiene_acceso
    from ba_usu_roles u,
         ba_rol_programas r
   where u.cod_usuario   = p_cod_usuario
     and u.cod_rol       = r.cod_rol
     and r.cod_programa  = 'GMCONUMB'
     and (r.inserta = 'S' or r.actualiza = 'S');
  
  --validar que pueda ver ctas. de empleados
  BEGIN
    SELECT NVL(ver_cta_empleados,'N')
      INTO v_cta_empleado
      FROM ba_usuarios
     WHERE cod_usuario = p_cod_usuario;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_cta_empleado := 'N';
  END;

  -----------------------------------------------------------------------------
  -- 1. Operaciones con umbral pendientes de Cumplimiento (Estado 'S')
  -- Solo se evalúa si el usuario tiene permiso para gestionar en GMCONUMB
  -----------------------------------------------------------------------------
  if v_tiene_acceso > 0 then
    if v_cta_empleado = 'S' then
      select count(*)
        into v_cant_pend
        from ge_movimientos mov
       where mov.estado = 'P'
         and mov.reversado = 'N'
         and pae_cnf.fu_obt_est_modulo(3) = 2
         and mov.nro_caja is not null
         and mov.cod_tra_padre = 351
         and exists (select 1
                       from ge_aut_umbral ped
                      where ped.cod_usuario = mov.cod_usuario
                        and ped.fecha       = mov.fecha
                        and ped.hora        = mov.hora
                        and ped.estado      = 'S')
         and nvl((select max(decode(fug_es_empleado(rel.cod_persona), 'S', 1, 0)) 
                    from ge_cta_clientes rel 
                   where rel.nro_cuenta = mov.nro_cuenta 
                     and rel.relacion = 'P'),0) in (0,1);
    else
      select count(*)
        into v_cant_pend
        from ge_movimientos mov
       where mov.estado = 'P'
         and mov.reversado = 'N'
         and pae_cnf.fu_obt_est_modulo(3) = 2
         and mov.nro_caja is not null
         and mov.cod_tra_padre = 351
         and exists (select 1
                       from ge_aut_umbral ped
                      where ped.cod_usuario = mov.cod_usuario
                        and ped.fecha       = mov.fecha
                        and ped.hora        = mov.hora
                        and ped.estado      = 'S')
         and nvl((select max(decode(fug_es_empleado(rel.cod_persona), 'S', 1, 0)) 
                    from ge_cta_clientes rel 
                   where rel.nro_cuenta = mov.nro_cuenta 
                     and rel.relacion = 'P'),0) = 0;
    end if;
  end if;
  -----------------------------------------------------------------------------
  -- Determinación de programa y mensaje
  -----------------------------------------------------------------------------
  if v_cant_pend > 0 then
     p_cod_programa := 'GMCONUMB';
     p_mensaje := 'Solicitud de autorización de depósito USD/GS por monto superior al umbral para Cumplimiento vía Bankitti (' || v_cant_pend || ' pendiente/s). Revisar';
  end if;

exception
  when others then
    p_cod_programa := null;
    p_mensaje      := null;
end;
/
