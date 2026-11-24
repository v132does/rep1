CREATE OR REPLACE PACKAGE BODY IT.PAR_CAM IS
/*Genera las personas asociadas a las campa풹s*/
PROCEDURE PR_GEN_CAM_PERSONAS
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 )
 IS
  vexiste      VARCHAR2(1) := 'N';
  vsegmento    VARCHAR2(10);
  vselect      LONG;
  vfec_actual  DATE;
  vmensaje     VARCHAR2(500);
  verror       EXCEPTION;
  i            VARCHAR2(1000);
BEGIN
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_PERSONAS DISABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAM_PERSONAS DISABLE', i);
  -- Verifica que existe la campa풹
  vmensaje := par_cam.fu_set_trigger( 'DISABLE' );
  IF vmensaje IS NOT NULL THEN
    raise verror;
  END IF;
  BEGIN
    select 'S', cod_segmento
      into vexiste, vsegmento
      from cr_campanas
     where cod_campana = p_cod_campana;
  EXCEPTION
    when verror then
      raise verror;
    when no_data_found then
      vsegmento := NULL;
      vexiste := 'N';
    when others then
      vsegmento := NULL;
      vmensaje := 'ERROR. Al buscar la campa풹 ' || to_char(p_cod_campana)||'; ' ||sqlerrm;
  END;
  IF vexiste = 'S' THEN
    -- Borra las personas relacionadas a la campa풹
    BEGIN
      delete cr_cam_personas
       where cod_campana = p_cod_campana;
    EXCEPTION
      when verror then
        raise verror;
      when others then
        vmensaje := 'ERROR. Al borrar las personas de la campa풹 ' || to_char(p_cod_campana)||'; ' ||sqlerrm;
        raise verror;
    END;
    -- Busca el segmento asociado a la campa풹, este contiene el select para seleccionar a las
    -- personas, dentro del campo DET_SQL.
    BEGIN
      select det_sql
        into vselect
        from cr_segmentos
       where cod_segmento = vsegmento;
    EXCEPTION
      when verror then
        raise verror;
      when others then
        vmensaje := 'ERROR. Al seleccionar el segmento de la campa풹 ' || to_char(p_cod_campana)||'; ' ||sqlerrm;
        raise verror;
    END;
    vfec_actual := pae_cnf.fu_obt_fec_actual( 12 );
    BEGIN
      -- Regenera las personas asociadas a la campa풹
      sql_util.ejecute_dml( 'insert into cr_cam_personas( cod_campana, '                          ||
                                                         'cod_persona, '                          ||
                                                         'estado ) '                              ||
                                                  'select distinct ' || p_cod_campana || ', '     ||
                                                         '"Codigo" as codigo, '                   ||
                                                         '1 '                                     ||
                                                     'from ( ' || vselect || ' ) a '              ||
                                                    'where NOT EXISTS( select 1 '                 ||
                                                                        'from cr_cam_personas b ' ||
                                                                       'where b.cod_campana = '   || p_cod_campana || ') ' ||
                                                      'and NOT EXISTS( select 1 '                 ||
                                                                        'from cr_agendas c, cr_age_est_actividades d '     ||
                                                                       'where c.cod_agenda > 0 '  ||
                                                                         'and c.cod_campana = '   || p_cod_campana || ' '  ||
                                                                         'and c.cod_persona = a."Codigo" '         ||
                                                                         'and c.cod_actividad = d.cod_actividad '  ||
                                                                         'and c.cod_estado = d.cod_estado '        ||
                                                                         'and nvl( d.ind_cancelacion, ''N'' ) = ''S'' )',
                            vmensaje );
      IF vmensaje IS NOT NULL THEN
        vmensaje := 'ERROR. Al insertar las personas del segmento; ' || vmensaje;
        rollback;
        raise verror;
      ELSE
        commit;
      END IF;
    EXCEPTION
      when verror then
        raise verror;
      when others then
        vmensaje := 'ERROR. Al regenerar la campa풹 ' || sqlerrm;
        raise verror;
    END;
    BEGIN
      -- Actualiza el usuario encargado de gestionar la actividad,
      -- tomando como referencia el ultimo usuario que realizo la gestion
      -- a la persona.
   /*   IF par_cam.c_tip_imp = 1 THEN
        -- Para Regional toma SIEMPRE para el responsable, el oficial del cliente
          update cr_cam_personas c
           set c.cod_usu_responsable = ( select t.cod_usu_oficial
                                           from ge_clientes t
                                          where t.cod_persona = c.cod_persona ),
               ( c.fec_ini_asignacion, c.cod_agenda ) = ( select h.fec_ini_asignacion, h.cod_agenda
                                                            from cr_cam_personas_his h
                                                           where h.cod_persona = c.cod_persona
                                                             and h.cod_campana = c.cod_campana
                                                             and trunc( h.fec_historial ) = vfec_actual )
         where c.cod_campana = p_cod_campana
           and c.cod_usu_responsable IS NULL;
      ELSE*/
        -- Para el resto de las implementaciones, busca el ultimo usuario que gestiono la actividad.
          update cr_cam_personas c
           set c.cod_usu_responsable = ( select h.cod_usu_responsable
                                           from cr_cam_personas_his h, cr_campanas a, ba_usuarios u
                                          where h.cod_persona = c.cod_persona
                                            and h.cod_campana = c.cod_campana
                                            and trunc( h.fec_historial ) = vfec_actual
                                            and h.cod_campana = a.cod_campana
                                            and ( ( a.tip_responsable = 'G' and instr( a.responsables, nvl( u.gru_agenda, '#' ) || '-' ) > 0 ) or
                                                  ( a.tip_responsable = 'U' and instr( a.responsables, u.cod_usuario || '-' ) > 0 ) )
                                            and nvl( u.estado, 'A' ) <> 'I'
                                            and h.cod_usu_responsable = u.cod_usuario ),
               ( c.fec_ini_asignacion, c.cod_agenda ) = ( select h.fec_ini_asignacion, h.cod_agenda
                                                            from cr_cam_personas_his h
                                                           where h.cod_persona = c.cod_persona
                                                             and h.cod_campana = c.cod_campana
                                                             and trunc( h.fec_historial ) = vfec_actual )
         where c.cod_campana = p_cod_campana
           and c.cod_usu_responsable IS NULL;
    --  END IF;
    EXCEPTION
      when verror then
        raise verror;
      when others then
        vmensaje := 'ERROR. Al borrar las personas fuera de segmento para la campa풹 ' || to_char(p_cod_campana)||'; ' ||sqlerrm;
        raise verror;
    END;
      IF vmensaje IS NOT NULL THEN
        vmensaje := 'ERROR. Al borrar las personas del segmento; ' || to_char(p_cod_campana)||'; ' ||vmensaje;
        rollback;
        raise verror;
      ELSE
        commit;
      END IF;
  END IF;
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_PERSONAS ENABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAM_PERSONAS ENABLE', i);
EXCEPTION
  when verror then
    i := par_cam.fu_set_trigger( 'ENABLE' );
    sql_util.ejecute_dml('ALTER TRIGGER AA_CR_PERSONAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAM_PERSONAS ENABLE', i);
    RAISE_APPLICATION_ERROR( -20000, vmensaje );
  when others then
    i := par_cam.fu_set_trigger( 'ENABLE' );
    sql_util.ejecute_dml('ALTER TRIGGER AA_CR_PERSONAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAM_PERSONAS ENABLE', i);
    RAISE_APPLICATION_ERROR( -20000, 'ERROR. En el proceso de regeneracion de personas ' || sqlerrm );
END;
/* Genera el historial de las personas asociadas a las campa풹s */
PROCEDURE PR_GEN_HIS_CAMPANAS
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 )
 IS
  vexiste     VARCHAR2(1) := 'N';
  vfec_actual DATE;
  vmensaje    VARCHAR2(500);
  verror      EXCEPTION;
  CURSOR historico
      IS select c.cod_campana, c.cod_persona, c.estado, a.fec_actividad, a.cod_estado, a.det_actividad,
                c.cod_usu_responsable, a.fec_ini_asignacion, a.cod_agenda
           from cr_cam_personas c, cr_agendas a
          where c.cod_campana = p_cod_campana
            and a.cod_campana = c.cod_campana
            and a.cod_persona = c.cod_persona
--            and nvl( a.automatico, 'N' ) = 'S'
            and a.cod_agenda = ( select max( b.cod_agenda )
                                   from cr_agendas b
                                  where b.cod_campana = a.cod_campana
                                    and b.cod_persona = a.cod_persona
                                    /*and nvl( a.automatico, 'N' ) = 'S'*/ )
          order by c.cod_campana, c.cod_persona, a.fec_actividad, a.cod_estado;
BEGIN
  vexiste := 'S';
  -- Verifica que exista la campa풹
  --BEGIN
    --select 'S'
    --  into vexiste
    --  from cr_campanas
    -- where cod_campana = p_cod_campana;
  --EXCEPTION
  --  when no_data_found then
  --    vexiste := 'N';
  --  when others then
  --    vmensaje := 'ERROR. Al buscar la campa풹 ' || sqlerrm;
  --END;
  -- Carga el historial
  vfec_actual := pae_cnf.fu_obt_fec_actual( 12 );
  BEGIN
    delete cr_cam_personas_his
      where fec_historial = vfec_actual
        and cod_campana = p_cod_campana;
  EXCEPTION
    when others then
      NULL;
  END;
  IF vexiste = 'S' THEN
    FOR h IN historico LOOP
      BEGIN
        insert into cr_cam_personas_his( fec_historial,
                                         cod_campana,
                                         cod_persona,
                                         estado,
                                         cod_estado_act,
                                         det_actividad,
                                         usu_insercion,
                                         fec_insercion,
                                         usu_modificacion,
                                         fec_modificacion,
                                         fec_actividad,
                                         cod_usu_responsable,
                                         fec_ini_asignacion,
                                         cod_agenda )
                                 values( vfec_actual,
                                         h.cod_campana,
                                         h.cod_persona,
                                         h.estado,
                                         h.cod_estado,
                                         h.det_actividad,
                                         substr( user, 1, 10 ),
                                         sysdate,
                                         substr( user, 1, 10 ),
                                         sysdate,
                                         h.fec_actividad,
                                         h.cod_usu_responsable,
                                         h.fec_ini_asignacion,
                                         h.cod_agenda );
      EXCEPTION
        when verror then
          raise verror;
        when others then
          vmensaje := 'ERROR. al insertar el historial ' || p_cod_campana || ', ' || h.cod_persona || sqlerrm;
          raise verror;
      END;
    END LOOP;
  END IF;
EXCEPTION
  when verror then
    RAISE_APPLICATION_ERROR( -20000, vmensaje );
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'ERROR. En el proceso de creacion del historial ' || sqlerrm );
END;
/* Actualiza las campa풹s a "Vencidas" cuando llegue la fecha de fin */
PROCEDURE PR_CAM_VENCIDA
 IS
  vfec_actual DATE;
BEGIN
  vfec_actual := pae_cnf.fu_obt_fec_actual( 12 );
  update cr_campanas
     set estado = 3
   where nvl( fec_vencimiento, to_date( '31/12/9999', 'DD/MM/YYYY' ) ) <= vfec_actual
     and nvl( estado, 1 ) = 2;
EXCEPTION
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'ERROR. No se pudieron actualizar las campa풹s vencidas ' || sqlerrm );
END;
/* Obtiene la lista de cuentas morosas de la persona */
FUNCTION FU_OBT_CTA_MOROSAS
 (P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE,
  P_FECHA       DATE
 )
 RETURN VARCHAR2
 IS
  vdetalle  VARCHAR2(2000);
  vlinea    VARCHAR2(500);
  vcontador NUMBER;
  CURSOR cuentas
      IS select initcap( decode( upper( substr( m.descripcion, -1 ) ), 'S', substr( m.descripcion, 1, ( nvl( length( m.descripcion ), 0 ) -1 ) ), m.descripcion ) ) desc_modulo,
                c.nro_cuenta, c.mto_mora, c.dia_atraso, c.cod_moneda, c.cod_modulo
           from ge_cta_clientes t, ge_cuentas c, ba_modulos m, ba_monedas d, ge_est_cuentas e
          where t.cod_persona = p_cod_persona
            and t.relacion IN( 'P' )
            and t.nro_cuenta = c.nro_cuenta
            and nvl( c.en_juicio, 'N' ) = 'N'
            and c.cod_modulo = m.cod_modulo
            and nvl( c.dia_atraso, 0 ) > 0
            and c.cod_moneda = d.cod_moneda
            and c.cod_modulo = e.cod_modulo
            and c.cod_modalidad = e.cod_modalidad
            and c.estado = e.estado
            and nvl( e.activo, 'N' ) = 'S'
          order by 1, c.cod_moneda, c.mto_mora, c.dia_atraso, c.nro_cuenta;
  FUNCTION lf_obt_fec_vencimiento( p_nro_cuenta GE_CUENTAS.NRO_CUENTA%TYPE,
                                   p_cod_modulo GE_CUENTAS.COD_MODULO%TYPE
                                   ) RETURN DATE IS
    vfec DATE;
  BEGIN
    IF p_cod_modulo = 5 THEN
      BEGIN
        select fec_vct_ult_cierre
          into vfec
          from ta_cta_tarjetas
         where nro_cuenta = p_nro_cuenta;
      EXCEPTION
        when others then
          vfec := NULL;
      END;
    ELSIF p_cod_modulo = 6 THEN
      BEGIN
        select min( c.fec_vencimiento )
          into vfec
          from pr_cta_prestamos p, pr_cuotas c
         where p.nro_cuenta = p_nro_cuenta
           and p.nro_cuenta = c.nro_cuenta
           and c.nro_cuota > 0
           and ( nvl( c.sal_capital, 0 ) + nvl( c.sal_interes, 0 ) + nvl( c.sal_int_documentado, 0 ) ) <> 0;
      EXCEPTION
        when others then
          vfec := NULL;
      END;
    END IF;
    return vfec;
  END;
BEGIN
  vcontador := 0;
  vdetalle := 'CUENTAS MOROSAS A LA FECHA:' || chr(10) ||
              '[Descripcion] / [Numero] / [Monto] / [Dias] / [Vencim]';
  FOR s IN cuentas LOOP
    vcontador := nvl( vcontador, 0 ) + 1;
    vlinea := to_char( vcontador ) || ') ' || s.desc_modulo || ' / ' ||
              s.nro_cuenta || ' / ' ||
              s.cod_moneda || ' ' || ltrim( rtrim( to_char( nvl( s.mto_mora, 0 ), '999,999,999,999,999,999,999,999,999,990.00' ) ) ) || ' / ' ||
              ltrim( rtrim( to_char( nvl( s.dia_atraso, 0 ), '999,999,990' ) ) ) || ' / ';
    IF s.cod_modulo = 5 THEN
      vlinea := vlinea || to_char( ( nvl( p_fecha, trunc( sysdate ) ) - nvl( s.dia_atraso, 0 ) ) - 1, 'DD/MM/YYYY' );
    ELSE
      vlinea := vlinea || to_char( lf_obt_fec_vencimiento( s.nro_cuenta,s.cod_modulo ), 'DD/MM/YYYY' );
    END IF;
    IF nvl( length( vdetalle ), 0 ) + nvl( length( vlinea ), 0 ) + 1 > 2000 THEN
      vdetalle := vdetalle || chr(10) || '...';
      EXIT;
    ELSE
      vdetalle := vdetalle || chr(10) || vlinea;
    END IF;
  END LOOP;
  IF vcontador = 0 THEN
    vdetalle := NULL;
  END IF;
  return vdetalle;
EXCEPTION
  when no_data_found then
    return NULL;
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'ERROR. Detalle de cuentas morosas. Persona: ' || P_COD_PERSONA || '; ' ||sqlerrm);
END;
/* Obtiene la lista de cuentas morosas de la persona para notas */
FUNCTION FU_OBT_CTA_MOR_NOT
 (P_COD_PERSONA BA_PERSONAS.COD_PERSONA%TYPE,
  P_FECHA       DATE
 )
 RETURN VARCHAR2
 IS
  vdetalle  VARCHAR2(2000);
  vlinea    VARCHAR2(500);
  vcontador NUMBER(03);
  v_cod_mon_local ba_monedas.cod_moneda%type;
  CURSOR cuentas
      IS select initcap( decode( upper( substr( m.descripcion, -1 ) ), 'S', substr( m.descripcion, 1, ( nvl( length( m.descripcion ), 0 ) -1 ) ), m.descripcion ) ) desc_modulo,
                c.nro_cuenta, c.mto_mora, c.dia_atraso, c.cod_moneda, c.cod_modulo
           from ge_cta_clientes t, ge_cuentas c, ba_modulos m, ba_monedas d, ge_est_cuentas e
          where t.cod_persona = p_cod_persona
            and t.relacion IN( 'P' )
            and t.nro_cuenta = c.nro_cuenta
            and nvl( c.en_juicio, 'N' ) = 'N'
            and c.cod_modulo = m.cod_modulo
            and nvl( c.dia_atraso, 0 ) > 0
            and c.cod_moneda = d.cod_moneda
            and c.cod_modulo = e.cod_modulo
            and c.cod_modalidad = e.cod_modalidad
            and c.estado = e.estado
            and nvl( e.activo, 'N' ) = 'S'
          order by 1, c.cod_moneda, c.mto_mora, c.dia_atraso, c.nro_cuenta;
BEGIN
  v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
  vcontador := 0;
  if fug_obt_tip_implementacion = 3 then
     vdetalle := 'En Atlas Ud. tiene:';
  else
     vdetalle := 'Ud. tiene:';
  end if;
  FOR s IN cuentas LOOP
    vcontador := nvl( vcontador, 0 ) + 1;
    if s.cod_modulo = 4 then
       vlinea := ' 1 Sobregiro ';
    elsif s.cod_modulo = 6 then
       vlinea := ' 1 Prest. moroso ';
    elsif s.cod_modulo = 5 then
       vlinea := ' 1 Tarj. morosa ';
    else
       vlinea := ' 1 '||s.desc_modulo||' ';
    end if;
    
    if v_cod_mon_local = s.cod_moneda then
       vlinea := vlinea||'d ' ||
                 s.cod_moneda || ' ' || ltrim( rtrim( to_char( nvl( s.mto_mora, 0 ), '999,999,999,999,999,999,999,999,999,990' ) ) ) || ' x ';
    else
       vlinea := vlinea||'d ' ||
                 s.cod_moneda || ' ' || ltrim( rtrim( to_char( nvl( s.mto_mora, 0 ), '999,999,999,999,999,999,999,999,999,990.00' ) ) ) || ' x ';
    end if;
    vlinea := vlinea||ltrim( rtrim( to_char( nvl( s.dia_atraso, 0 ), '999,999,990' ) ) ) || ' dias';
    IF nvl( length( vdetalle ), 0 ) + nvl( length( vlinea ), 0 ) + 1 > 2000 THEN
      vdetalle := vdetalle ||','|| '...';
      EXIT;
    ELSE
      if vcontador = 1 then
         vdetalle := vdetalle||vlinea;
      else
         vdetalle := vdetalle || ',' || vlinea;
      end if;
    END IF;
  END LOOP;
  IF vcontador = 0 THEN
    vdetalle := NULL;
  END IF;
  return vdetalle;
EXCEPTION
  when no_data_found then
    return NULL;
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'ERROR. Detalle de cuentas morosas. Persona: ' || P_COD_PERSONA || '; ' ||sqlerrm);
END;
PROCEDURE PR_INS_AGENDA( P_COD_CAMPANA IN  CR_CAMPANAS.COD_CAMPANA%TYPE,
                         P_REG         IN  CR_AGENDAS%ROWTYPE,
                         P_MENSAJE     OUT VARCHAR2
                         ) IS
  /*
  || Inserta el registro de agenda y actualiza la tabla CR_CAM_PERSONAS
  || y indicando que la actividad fue generada.
  */
  v_nro CR_AGENDAS.COD_AGENDA%TYPE;
BEGIN
  BEGIN
    select s_cod_agenda.nextval
      into v_nro
      from dual;
  EXCEPTION
    when others then
      v_nro := 1;
  END;
  BEGIN
    insert into cr_agendas( cod_agenda,
                            cod_persona,
                            cod_usu_encargado,
                            fec_actividad,
                            cod_mot_actividad,
                            cod_actividad,
                            det_actividad,
                            cod_estado,
                            automatico,
                            cod_campana,
                            dia_atraso,
                            mto_mora,
                            fec_ini_asignacion,
                            mto_capital )
                    values( v_nro,
                            p_reg.cod_persona,
                            p_reg.cod_usu_encargado,
                            trunc( p_reg.fec_actividad ),
                            p_reg.cod_mot_actividad,
                            p_reg.cod_actividad,
                            p_reg.det_actividad,
                            p_reg.cod_estado,
                            p_reg.automatico,
                            nvl( p_reg.cod_campana, p_cod_campana ),
                            p_reg.dia_atraso,
                            p_reg.mto_mora,
                            p_reg.fec_ini_asignacion,
                            p_reg.mto_capital );
  EXCEPTION
    when others then
      p_mensaje := 'ERROR. No se pudo generar la agenda ' || sqlerrm;
  END;
  IF p_mensaje IS NULL THEN
    BEGIN
      -- actualizo el responsable de la agenda
      update cr_cam_personas
         set cod_usu_responsable = p_reg.cod_usu_encargado,
             cod_agenda = v_nro
       where cod_campana = p_cod_campana
         and cod_persona = p_reg.cod_persona;
    EXCEPTION
      when others then
        p_mensaje := 'ERROR. No se pudo asignar el responsable de la agenda ' || sqlerrm;
    END;
  END IF;
EXCEPTION
  when others then
    p_mensaje := 'ERROR. En el proceso de insercion de la agenda ' || sqlerrm;
END;
FUNCTION FU_TOT_USUARIOS( P_TIP_RESPONSABLE IN VARCHAR2,
                          P_RESPONSABLES    IN VARCHAR2
                          ) RETURN NUMBER IS
  /*
  || Cuenta la cantidad de usuarios asignados para la ejecucion
  || de la campa풹
  */
  i NUMBER;
BEGIN
  -- Cuenta la cantidad de usuarios elegidos para ser agendados ---
  Select count(*)
    into i
    from ba_usuarios
   where ( p_tip_responsable = 'G' and instr( p_responsables, nvl( gru_agenda, '#' ) || '-' ) > 0 )
      or ( p_tip_responsable = 'U' and instr( p_responsables, cod_usuario || '-' ) > 0 )
     and estado <> 'I';
  return i;
EXCEPTION
  when others then
    return 0;
END;
/*
FUNCTION LF_TOT_PERSONAS( P_CAMPANA IN NUMBER ) RETURN NUMBER IS

--  || Cuenta la cantidad de personas asignadas a la campa풹.

  i NUMBER;
BEGIN
  BEGIN
    select count(*)
      into i
      from cr_cam_personas
     where cod_campana = p_campana
       and estado = 1;
  EXCEPTION
    when others then
      i := 0;
  END;
  return i;
EXCEPTION
  when others then
    return 0;
END;
*/
FUNCTION FU_OBT_OFI_USUARIO( P_COD_USUARIO IN VARCHAR2 ) RETURN NUMBER IS
  /*
  || Obtiene la oficina del usuario.
  */
  i NUMBER(3);
BEGIN
  select cod_oficina
    into i
    from ba_usuarios
   where cod_usuario = p_cod_usuario;
  return i;
EXCEPTION
  when others then
    return NULL;
END;
PROCEDURE PR_OBT_ATRASO( P_COD_PERSONA IN  VARCHAR2,
                         P_MAX_DIA     OUT NUMBER,
                         P_MTO_MORA    OUT NUMBER
                         ) IS
  /*
  || Obtiene la la cantidad maxima de dias de atraso y la suma de mora en guaranies.
  */
  v_dia NUMBER(6);
  v_mto NUMBER(18,2);
BEGIN
  BEGIN
    select max( c.dia_atraso ),
           sum( decode( c.cod_moneda, pag_gen.fu_obt_mon_local, nvl( c.mto_mora, 0 ),
                                      PAG_GEN.FU_CON_MON_A_MONEDA( c.cod_moneda, pag_gen.fu_obt_mon_local, nvl( c.mto_mora, 0 ) ) ) )
      into v_dia, v_mto
      from ge_cta_clientes l, ge_cuentas c, ge_est_cuentas e
     where l.cod_persona = p_cod_persona
       and l.nro_cuenta = c.nro_cuenta
       and nvl( c.dia_atraso, 0 ) > 0
       and e.cod_modulo = c.cod_modulo
       and e.cod_modalidad = c.cod_modalidad
       and e.estado = c.estado
       and nvl( e.activo, 'N' ) = 'S';
  EXCEPTION
    when others then
      v_dia := 0;
      v_mto := 0;
  END;
  p_max_dia := v_dia;
  p_mto_mora := v_mto;
END;
PROCEDURE PR_VER_ACT_PENDIENTES( P_COD_CAMPANA     IN CR_CAMPANAS.COD_CAMPANA%TYPE,
                                 P_COD_PERSONA     IN  BA_PERSONAS.COD_PERSONA%TYPE,
                                 P_DET_ACTIVIDAD   IN  VARCHAR2,
                                 P_CAN_ACTIVIDADES OUT NUMBER
                                 ) IS
  /*
  || Verifica que no hayan actividades pendientes para el cliente.
  */
  i NUMBER;
  vfec_actual DATE := pae_cnf.fu_obt_fec_actual( 12 );
  CURSOR agendas
      IS select a.cod_agenda
           from cr_agendas a
          where a.cod_campana = p_cod_campana
            and a.cod_persona = p_cod_persona
            and a.cod_estado IN( select cod_estado
                                   from cr_age_est_actividades
                                  where cod_actividad = a.cod_actividad
                                    and cod_estado = a.cod_estado
                                    and nvl( grupo, 'P' ) = 'P' )
            and a.fec_actividad > vfec_actual
          order by a.cod_agenda;
BEGIN
  -- Actualiza las agendas con fechas posteriores a la fecha de proceso y le asigna
  -- la descripcion generada para esa persona.
  i := 0;
  FOR g IN agendas LOOP
    BEGIN
      update cr_agendas
         set det_actividad = p_det_actividad
       where cod_agenda = g.cod_agenda;
    EXCEPTION
      when others then
        NULL;
    END;
    i := nvl( i, 0 ) + 1;
  END LOOP;
  p_can_actividades := i;
END;
/* Habilita/Deshabilita los trigger utilizados en los procesos de agenda. */
FUNCTION FU_SET_TRIGGER( P_ESTADO VARCHAR2 ) RETURN VARCHAR2 IS
  v_msj VARCHAR2(500);
  v_err EXCEPTION;
BEGIN
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_AGENDAS ' || p_estado, v_msj );
  IF v_msj IS NOT NULL THEN
    raise v_err;
  END IF;
/*
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_CAM_PERSONAS ' || p_estado, v_msj );
  IF v_msj IS NOT NULL THEN
    raise v_err;
  END IF;
*/
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_CAMPANAS ' || p_estado, v_msj );
  IF v_msj IS NOT NULL THEN
    raise v_err;
  END IF;
  return NULL;
EXCEPTION
  when v_err then
    return v_msj;
END;
/* Genera la agenda de las campa풹s para los usuarios */
PROCEDURE PR_GEN_AGENDA( P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE ) IS
  /*
  || Procedimiento encargado de generar las actividades en la agendas para
  || los diferentes tipos de campa풹s. Hasta el momento el proceso reacciona
  || solo a Campa풹s de Cobranzas y el resto de las campa풹s.
  */
  vfec_actual DATE := pae_cnf.fu_obt_fec_actual( 12 );
  CURSOR usuarios( p_tip_responsable VARCHAR2, p_responsables VARCHAR2 )
      /*
      || Si la campa풹 NO es de cobranza, entonces busca los usuarios definidos para la misma
      || y los ordena por usuario.
      */
      IS select u.cod_usuario, count( decode( par_cam.c_tip_imp, /*1*/0, 
      NULL, p.cod_usu_responsable ) )
           from ba_usuarios u, cr_cam_personas p
           /*FB.28.06.2010 agrego concatenacion de espacio en texto a buscar y el texto buscado*/
          where ( ( p_tip_responsable = 'G' and instr( ' '||p_responsables, ' '||nvl( u.gru_agenda, '#' ) || '-' ) > 0 ) OR
                  ( p_tip_responsable = 'U' and instr( ' '||p_responsables, ' '||u.cod_usuario || '-' ) > 0 ) )
            and u.estado <> 'I'
            and u.cod_usuario = p.cod_usu_responsable(+)
            and p_cod_campana = p.cod_campana(+)
          group by u.cod_usuario
          order by 2, decode( par_cam.c_tip_imp, /*1*/0, u.cod_usuario, lpad( to_char( fue_obt_num_aleatorio ), 50, ' ' ) );
  CURSOR personas( p_solo_nuevos VARCHAR2 )
      /*
      || Aqui obtiene las personas que componen el segmento pertenecientes a la campa풹 y
      || que todavia no fueron gestionadas.
      */
      IS select c.cod_persona, c.cod_usu_responsable, c.fec_ini_asignacion
           from cr_cam_personas c
          where c.cod_campana = p_cod_campana
            and c.estado = 1
            and ( ( p_solo_nuevos = 'S' and
                    c.cod_usu_responsable IS NULL ) OR
                  ( p_solo_nuevos = 'N' and
                    c.cod_usu_responsable IS NOT NULL and
                    -- Esto se agrego para cuando se procesa mas de 1 vez en el mismo dia.
                    -- PPalella, 13/09/2005
                    NOT EXISTS( select 1
                                  from cr_agendas a, cr_age_est_actividades e
                                 where a.cod_agenda > 0
                                   and trunc( a.fec_actividad ) = vfec_actual
                                   and a.cod_campana = c.cod_campana
                                   and a.cod_persona = c.cod_persona
                                   and a.cod_actividad = e.cod_actividad
                                   and a.cod_estado = e.cod_estado
                                   and nvl( e.grupo, 'P' ) <> 'P' ) ) )
          order by decode( p_solo_nuevos, 'S', cod_persona, cod_usu_responsable );
  v_automatico      VARCHAR2(1);
  v_age_generada    VARCHAR2(1); --Agenda generada manualmente
  v_ind_agenda      VARCHAR2(1); --Debe generar la Agenda
  v_tip_responsable VARCHAR2(1);
  v_responsables    VARCHAR2(1000);
  v_can_act_diario  NUMBER(8);
  v_fec_ini         DATE;
  v_fec_ini_activ   DATE;
  us                USUARIOS%ROWTYPE;
  v_can_usuarios    NUMBER(8);
  v_can_act_actual  NUMBER(8);
  v_usu_oficina     NUMBER(3);
  v_mensaje         VARCHAR2(500);
  v_error           EXCEPTION;
  v_mot_cobranza    VARCHAR2(5);
  r_agenda          CR_AGENDAS%ROWTYPE;
  v_usuario_ant     BA_USUARIOS.COD_USUARIO%TYPE;
  i                 VARCHAR2(1000);
  v_not_detalle     cr_campanas.not_detalle%type;
  v_det_act_original cr_campanas.detalle%type;
  
BEGIN
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_CAMPANAS DISABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAMPANAS DISABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_AGENDAS DISABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AB_CR_AGENDAS DISABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_PERSONAS DISABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAM_PERSONAS DISABLE', i);
  /*
  || Desabilita los triggers de las tablas que van a ser generadas
  || si se produce un error, termina el proceso.
  */
  v_mensaje := par_cam.fu_set_trigger( 'DISABLE' );
  IF v_mensaje IS NOT NULL THEN
    raise v_error;
  END IF;
  -- Selecciona los datos de la campa풹 para poder realizar el proceso mas tarde.
  v_det_act_original := null;
  BEGIN
    select automatico, age_generada, gen_agenda, tip_responsable, responsables, detalle, can_act_diario,
           fec_ini_actividad, cod_actividad, cod_mot_actividad, not_detalle
      into v_automatico, v_age_generada, v_ind_agenda, v_tip_responsable, v_responsables, r_agenda.det_actividad,
           v_can_act_diario, v_fec_ini, r_agenda.cod_actividad, r_agenda.cod_mot_actividad,v_not_detalle
      from cr_campanas
     where cod_campana = p_cod_campana;
     v_det_act_original := r_agenda.det_actividad;
  EXCEPTION
    when v_error then
      raise v_error;
    when others then
      v_mensaje := 'ERROR. El codigo de campa풹 no existe';
      raise v_error;
  END;
  -- Si la agenda ya se genero anteriormente, entonces da un error y termina el proceso
  IF v_age_generada = 'S' AND
     v_automatico = 'N' THEN
    v_mensaje := 'ERROR. Agenda ya ha sido generada anteriormente';
    raise v_error;
  END IF;
  IF v_fec_ini < vfec_actual THEN
    v_fec_ini := vfec_actual;
  END IF;
  v_fec_ini_activ := v_fec_ini;
  /*
  || Verifica que sea automatica, si es asi inicializa el campo de agenda generada, para tener
  || un estado actual del proceso.
  */
  IF v_automatico = 'S' THEN
    BEGIN
      update cr_campanas
         set age_generada = 'N'
       where cod_campana = p_cod_campana;
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudo inicializar la campa풹 '||to_char(p_cod_campana)||'; ' ||sqlerrm;
        raise v_error;
    END;
    /*
    || Borra las actividades Pendientes en la agenda, cuyos Clientes no se encuentren
    || en la segmentacion de la Campa풹
    */
    BEGIN
      delete cr_agendas a
       where a.cod_campana = p_cod_campana
         and a.cod_estado IN( select cod_estado
                                from cr_age_est_actividades
                               where cod_actividad = a.cod_actividad
                                 and cod_estado = a.cod_estado
                                 and nvl( grupo, 'P' ) = 'P' )
         and a.cod_persona NOT IN( select cod_persona
                                     from cr_cam_personas
                                    where cod_campana = a.cod_campana );
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudo borrar los datos viejos de la campa풹 '||to_char(p_cod_campana)||'; ' ||sqlerrm;
        raise v_error;
    END;
    /*
    || Borra las actividades de COBRANZAS que ya no se encuentran en la Campa풹
    || ==> 23/08/05: PPalella: Este procedimiento se comento a pedido de la gente
    ||                         de Atlas. Ver mas adelante como va a quedar.
    */
    /*
    BEGIN
      delete co_actividades a
       where a.cod_campana = p_cod_campana
         and a.cod_agenda IN( select g.cod_agenda
                                from cr_agendas g
                               where g.cod_campana = p_cod_campana
                                 and g.cod_estado IN( select cod_estado
                                                        from cr_age_est_actividades
                                                       where cod_actividad = g.cod_actividad
                                                         and cod_estado = g.cod_estado
                                                         and nvl( grupo, 'P' ) = 'P' )
                                 and g.cod_persona NOT IN( select cod_persona
                                                             from cr_cam_personas
                                                            where cod_campana = g.cod_campana ) );
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudo borrar los datos viejos de la campa풹 en COBRANZAS '||sqlerrm;
        raise v_error;
    END;
    ------------------------------------------ HASTA ACA SE COMENTO ------------------------------------------
    */
    BEGIN
      /*
      || Se borran las acividades pendientes en la agenda cuya fecha de asignacion sea menor
      || o igual a la fecha del modulo
      */
      delete cr_agendas a
       where a.cod_agenda IN( select b.cod_agenda
                                from cr_agendas b
                               where b.cod_campana = p_cod_campana
                                 and b.cod_estado IN( select c.cod_estado
                                                        from cr_age_est_actividades c
                                                       where c.cod_actividad = b.cod_actividad
                                                         and c.cod_estado = b.cod_estado
                                                         and nvl( c.grupo, 'P' ) = 'P' )
                                 and b.fec_actividad <= vfec_actual );
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudieron borrar las actividades pendientes del dia de ayer, para la campa풹 '||to_char(p_cod_campana)||'; ' ||sqlerrm;
        raise v_error;
    END;
  END IF;
  -- Busca el parametro que indica la actividad correspondiente a "Gestion de Cobranzas".
  v_mot_cobranza := fug_obt_pardinamico( 'COD_ACT_COBRANZA' );
  IF r_agenda.cod_actividad <> v_mot_cobranza THEN
    /*
    || Busca la cantidad de usuarios que fueron asignados para realizar las
    || tareas de esta campa풹. Si no encuentra ningun usuario asignado, entoces
    || muestra un error y termina el proceso.
    */
    v_can_usuarios := par_cam.fu_tot_usuarios( v_tip_responsable, v_responsables );
    IF v_can_usuarios <= 0 THEN
      v_mensaje := 'ERROR. No se ha seleccionado ni un solo responsable.';
      raise v_error;
    END IF;
  END IF;
  /*
  || Aqui se asignan los usuarios responsables a las actividades nuevas generadas
  || en la tabla CR_CAM_PERSONAS, pera luego generar las actividades a dichos usuarios.
  */
  IF usuarios%isopen THEN
    close usuarios;
  END IF;
  IF r_agenda.cod_actividad = v_mot_cobranza THEN
    -- Esta seccion es utilizada para Regional
    FOR pe IN personas( 'S' ) LOOP
      -- Actualiza el usuario de la campa풹, al cual se le generara la actividad mas adelante.
      DECLARE
        v_usu VARCHAR2(10);
      BEGIN
        BEGIN
          select cod_usu_oficial
            into v_usu
            from ge_clientes
           where cod_persona = pe.cod_persona;
        EXCEPTION
          when v_error then
            raise v_error;
          when others then
            v_mensaje := 'Se produjo un error al buscar el oficial de la persona ' || pe.cod_persona || '; ' || sqlerrm;
            raise v_error;
        END;
        BEGIN
          update cr_cam_personas
             set cod_usu_responsable = v_usu,
                 fec_ini_asignacion = vfec_actual
           where cod_campana = p_cod_campana
             and cod_persona = pe.cod_persona;
        EXCEPTION
          when v_error then
            raise v_error;
          when others then
            v_mensaje := 'ERROR. Al actualizar el responsable de la agenda ' || sqlerrm;
            raise v_error;
        END;
      END;
    END LOOP;
  ELSE
    -- Esta seccion no es utilizada para Regional
    OPEN usuarios( v_tip_responsable, v_responsables );
    FOR pe IN personas( 'S' ) LOOP
      /*
      || Carga los valores del cursor USUARIOS en la variable US, al llegar al final
      || del cursor (%notfound), lo cierra y lo vuelve a abrir hasta completar el proceso.
      */
      FETCH usuarios INTO us;
      IF usuarios%notfound THEN
        CLOSE usuarios;
        OPEN usuarios( v_tip_responsable, v_responsables );
        FETCH usuarios INTO us;
      END IF;
      -- Actualiza el usuario de la campa풹, al cual se le generara la actividad mas adelante.
      BEGIN
        update cr_cam_personas
           set cod_usu_responsable = us.cod_usuario,
               fec_ini_asignacion = vfec_actual
         where cod_campana = p_cod_campana
           and cod_persona = pe.cod_persona;
      EXCEPTION
        when v_error then
          raise v_error;
        when others then
          v_mensaje := 'ERROR. Al actualizar el responsable de la agenda ' || sqlerrm;
          raise v_error;
      END;
    END LOOP;
    IF usuarios%isopen THEN
      close usuarios;
    END IF;
  END IF;
  /*
  || Una vez cargados los datos de los usuarios, procede a generar las actividades para cada
  || usuario, de acuerdo a la cantidad de actividades definidas por dia.
  */
  FOR pe IN personas( 'N' ) LOOP
    IF nvl( v_usuario_ant, 'x' ) <> pe.cod_usu_responsable THEN
      -- Obtiene la oficina del usuario e inicializa el contador de actividades diarias.
      v_usu_oficina := par_cam.fu_obt_ofi_usuario( us.cod_usuario );
      v_fec_ini := v_fec_ini_activ;
      LOOP
        BEGIN
          select nvl( count(*), 0 )
            into v_can_act_actual
            from cr_agendas
           where trunc( fec_actividad ) = v_fec_ini
             and cod_usu_encargado = pe.cod_usu_responsable
             and cod_campana = p_cod_campana;
        EXCEPTION
          when v_error then
            raise v_error;
          when others then
            v_can_act_actual := 0;
        END;
        IF v_can_act_actual >= v_can_act_diario THEN
          v_fec_ini := pag_cal.fu_obt_fec_sig_hab( v_fec_ini, v_usu_oficina );
          v_can_act_actual := 0;
        ELSE
          EXIT;
        END IF;
      END LOOP;
    END IF;
    /*
    || Verifica que no se haya llegado al final de asignaciones diarias por usuarios
    || de ser asi, busca el siguiente dia habil.
    */
    IF v_can_act_actual >= v_can_act_diario THEN
      v_fec_ini := pag_cal.fu_obt_fec_sig_hab( v_fec_ini, v_usu_oficina );
      v_can_act_actual := 0;
      LOOP
        BEGIN
          select nvl( count(*), 0 )
            into v_can_act_actual
            from cr_agendas
           where trunc( fec_actividad ) = v_fec_ini
             and cod_usu_encargado = pe.cod_usu_responsable
             and cod_campana = p_cod_campana;
        EXCEPTION
          when v_error then
            raise v_error;
          when others then
            v_can_act_actual := 0;
        END;
        IF v_can_act_actual >= v_can_act_diario THEN
          v_fec_ini := pag_cal.fu_obt_fec_sig_hab( v_fec_ini, v_usu_oficina );
          v_can_act_actual := 0;
        ELSE
          EXIT;
        END IF;
      END LOOP;
    END IF;
    r_agenda.fec_actividad := v_fec_ini;
    /*
    || Suma la cantidad de actividades procesadas, luego si la actividad es de cobranzas,
    || reemplaza la observacion original de la actividad por el el detalle de cuentas morosas
    || y por ultimo obtiene la cantidad de dias de atraso y el monto en mora del cliente.
    */
    v_can_act_actual := v_can_act_actual + 1;
    -- Si la actividad de la agenda corresponde a Cobranzas, realiza el proceso.
    r_agenda.dia_atraso := NULL;
    r_agenda.mto_mora := NULL;
    IF nvl( r_agenda.cod_actividad, 1 ) = v_mot_cobranza THEN
      r_agenda.det_actividad := substr( '[' || to_char( pe.fec_ini_asignacion, 'DD/MM/YYYY' ) || '] - ' || nvl( par_cam.fu_obt_cta_morosas( pe.cod_persona, r_agenda.fec_actividad ), r_agenda.det_actividad ), 1, 2000 );
      par_cam.pr_obt_atraso( pe.cod_persona, r_agenda.dia_atraso, r_agenda.mto_mora );
--dbms_output.put_line( pe.cod_persona || ', ' || to_char( r_agenda.dia_atraso ) || ', ' || to_char( r_agenda.mto_mora ) );
    ELSIF INSTR(upper(trim(v_det_act_original)),'SELECT') = 1 THEN
       -- es un select dinamico se debe ejecutar para obtener el detalle de la actividad
       r_agenda.det_actividad := replace(v_det_act_original,'&COD_PERSONA',pe.cod_persona);
       r_agenda.det_actividad := fuj_pro_val_posibles(r_agenda.det_actividad,'N');
       if length(r_agenda.det_actividad) > 2 then
           -- se genero el dato
           r_agenda.det_actividad := replace(substr(r_agenda.det_actividad,2),'#',chr(10));
       else
            r_agenda.det_actividad := 'Sentencia Dinamica: '||replace(v_det_act_original,'&COD_PERSONA',pe.cod_persona)||' sin Datos. Avise a Informatica!';
       end if;
    END IF;
    DECLARE
      e NUMBER;
    BEGIN
      /*
      || Actualiza las agendas con fechas posteriores a la fecha de proceso y le asigna
      || la descripcion generada para esa persona.
      */
      par_cam.pr_ver_act_pendientes( p_cod_campana, pe.cod_persona, r_agenda.det_actividad, e );
      /*
      || Si el proceso anterior no encontro ninguna actividad a futuro (Reprogramada), entonces
      || inserta un registro en la agenda para el usuario y la persona.
      */
      IF nvl( e, 0 ) = 0 THEN
        r_agenda.cod_persona := pe.cod_persona;
        r_agenda.cod_usu_encargado := pe.cod_usu_responsable;
        r_agenda.fec_ini_asignacion := pe.fec_ini_asignacion;
        r_agenda.cod_estado := 1;
        r_agenda.automatico := 'S';
        r_agenda.cod_campana := p_cod_campana;
        ---
        r_agenda.mto_capital := nvl(FUG_OBT_ACTIVO_CLIENTE(pe.cod_persona),0);
        ---
        -- Inserta el registro, si se produce un error termina el proceso con un error.
        par_cam.pr_ins_agenda( p_cod_campana, r_agenda, v_mensaje );
        IF v_mensaje IS NOT NULL THEN
          raise v_error;
        END IF;
      END IF;
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. Al verificar la insercion/actualizacion de la agenda ' || sqlerrm;
        raise v_error;
    END;
    v_usuario_ant := pe.cod_usu_responsable;
  END LOOP;
  -- Carga los datos de las cuentas morosas relacionadas a esta campa풹.
  --IF par_cam.c_tip_imp <> 1 THEN
    par_cam.pr_gen_act_cobranza( p_cod_campana );
    par_cam.pr_ctl_pag_cobranza( p_cod_campana );
  --END IF;
  -- Actualiza la campa풹 para indicar que se ha generado correctamente la agenda de clientes.
  BEGIN
    update cr_campanas
       set age_generada = 'S'
     where cod_campana = p_cod_campana;
  EXCEPTION
    when v_error then
      raise v_error;
    when others then
      v_mensaje := 'ERROR. No se pudo actualizar la campa풹 actual '||sqlerrm;
      raise v_error;
  END;
  -- Vuelve a activar los triggers previamente desabilitados, para que todo quede como al principio.
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_CAMPANAS ENABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAMPANAS ENABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_AGENDAS ENABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AB_CR_AGENDAS ENABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AA_CR_PERSONAS ENABLE', i);
  sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAM_PERSONAS ENABLE', i);
  v_mensaje := par_cam.fu_set_trigger( 'ENABLE' );
  IF v_mensaje IS NOT NULL THEN
    raise v_error;
  END IF;
EXCEPTION
  when v_error then
    i := par_cam.fu_set_trigger( 'ENABLE' );
    sql_util.ejecute_dml('ALTER TRIGGER AA_CR_CAMPANAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAMPANAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AA_CR_AGENDAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AB_CR_AGENDAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AA_CR_PERSONAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAM_PERSONAS ENABLE', i);
    RAISE_APPLICATION_ERROR(-20000, v_mensaje );
  when others then
    i := par_cam.fu_set_trigger( 'ENABLE' );
    sql_util.ejecute_dml('ALTER TRIGGER AA_CR_CAMPANAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAMPANAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AA_CR_AGENDAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AB_CR_AGENDAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AA_CR_PERSONAS ENABLE', i);
    sql_util.ejecute_dml('ALTER TRIGGER AB_CR_CAM_PERSONAS ENABLE', i);
    RAISE_APPLICATION_ERROR(-20000, 'ERROR. en p_genera_agenda '||sqlerrm);
END;
/* Genera notas de las campa풹s para los usuarios */
PROCEDURE PR_GEN_NOTA
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 )
 IS
  v_automat   VARCHAR2(1);
  v_not_gen   VARCHAR2(1); --Nota generada anteriormente
  v_ind_not   VARCHAR2(1); --Debe generar la Nota
  v_descrip   VARCHAR2(50);
  v_detalle   VARCHAR2(500);
  v_fec_ini   DATE;
  v_tipo      VARCHAR2(1);
  v_medio     VARCHAR2(1);
  v_cont      NUMBER;
  vfec_actual DATE := pae_cnf.fu_obt_fec_actual( 12 );
  v_mensaje   VARCHAR2(500);
  v_error     EXCEPTION;
  v_not_detalle cr_campanas.not_detalle%type;
  
BEGIN
  BEGIN
    select automatico, not_generada, gen_nota, descripcion, detalle, fec_ini_actividad, not_tipo, not_medio,not_detalle
      into v_automat, v_not_gen, v_ind_not, v_descrip, v_detalle, v_fec_ini, v_tipo, v_medio, v_not_detalle
      from cr_campanas
     where cod_campana = p_cod_campana;
  EXCEPTION
    when others then
      v_mensaje := 'ERROR. El codigo de campa풹 no existe';
      raise v_error;
  END;
  IF v_not_gen = 'S' AND
     v_automat = 'N' THEN
    v_mensaje := 'ERROR. Las Notas a las personas ya fueron generadas anteriormente';
    raise v_error;
  END IF;
  IF v_automat = 'S' THEN
    BEGIN
      update cr_campanas
         set not_generada = 'N'
       where cod_campana = p_cod_campana;
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudo inicializar la campa풹 actual '||sqlerrm;
        raise v_error;
    END;
    BEGIN
      delete cr_per_notas n
       where n.cod_campana = p_cod_campana
         and n.estado = 'P'
         and ( ( n.fecha <= vfec_actual ) OR
               ( n.cod_persona NOT IN( select cod_persona
                                         from cr_cam_personas
                                        where cod_campana = n.cod_campana ) ) );
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudo borrar los datos viejos de la campa풹 '||sqlerrm;
        raise v_error;
    END;
  END IF;
  -- Verifica que hayan registros pendientes a futuro para actualizar sus detalles
  v_cont := 0;
  BEGIN
    select count(*)
      into v_cont
      from cr_per_notas n
     where n.cod_campana = p_cod_campana
       and n.estado = 'P'
       and n.fecha > vfec_actual
       and cod_persona IN( select cod_persona
                             from cr_cam_personas
                            where cod_campana = p_cod_campana );
  EXCEPTION
    when v_error then
      raise v_error;
    when others then
      v_cont := 0;
  END;

  IF v_cont > 0 THEN
    BEGIN
      update cr_per_notas n
         set descripcion = v_descrip,
             detalle = decode(v_tipo,'O',substr( nvl( par_cam.fu_obt_cta_mor_not( n.cod_persona, vfec_actual ), v_detalle ), 1, 2000 ),v_detalle)
       where n.cod_campana = p_cod_campana
         and n.estado = 'P'
         and n.fecha > vfec_actual
         and cod_persona IN( select cod_persona
                               from cr_cam_personas
                              where cod_campana = p_cod_campana );
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudo actualizar las notas de la campa풹 '||sqlerrm;
        raise v_error;
    END;
  END IF;
  BEGIN
    insert into cr_per_notas( cod_persona,
                              tipo,
                              fecha,
                              descripcion,
                              cod_campana,
                              detalle,
                              automatico,
                              estado,
                              medio )
                       Select c.cod_persona,
                              v_tipo,
                              v_fec_ini,
                              v_descrip,
                              p_cod_campana,
                              decode(v_tipo,'O',substr( nvl( par_cam.fu_obt_cta_mor_not( c.cod_persona, vfec_actual ), v_detalle ), 1, 2000 ),v_detalle||' '||CHR(10)||v_not_detalle),
                              'S',
                              'P',
                              v_medio
                         from cr_cam_personas c
                        where c.cod_campana = p_cod_campana
                          and c.cod_persona NOT IN( select cod_persona
                                                      from cr_per_notas
                                                     where cod_campana = c.cod_campana
                                                       and cod_persona = c.cod_persona
                                                       and estado = 'P'
                                                       and fecha > vfec_actual );
  EXCEPTION
    when v_error then
      raise v_error;
    when others then
      v_mensaje := 'ERROR. No se pudieron insertar las notas de la campa풹 '||sqlerrm;
      raise v_error;
  END;
  BEGIN
    update cr_campanas
       set not_generada = 'S'
     where cod_campana = p_cod_campana;
  EXCEPTION
    when v_error then
      raise v_error;
    when others then
      v_mensaje := 'ERROR. No se pudo actualizar la campa풹 actual '||sqlerrm;
      raise v_error;
  END;
EXCEPTION
  when v_error then
    RAISE_APPLICATION_ERROR(-20000, v_mensaje );
  when others then
    RAISE_APPLICATION_ERROR(-20000, 'ERROR. en p_genera_nota '||sqlerrm);
END;
/* Genera los emails para los clientes de las campa풹s */
PROCEDURE PR_GEN_EMAIL
 (P_COD_CAMPANA IN CR_CAMPANAS.COD_CAMPANA%TYPE
 )
 IS
  CURSOR personas
      IS select p.cod_persona, p.nom_completo, p.dir_correo, c.ema_asunto, c.ema_detalle
           from cr_campanas c, cr_cam_personas a, ba_personas p
          where c.cod_campana = p_cod_campana
            and c.cod_campana = a.cod_campana
            and p.cod_persona = a.cod_persona
            and p.dir_correo is not null
            and nvl( c.gen_mail, 'N' ) = 'S'
          order by a.cod_persona;
  v_automat VARCHAR2(1);
  v_ema_gen VARCHAR2(1); --Email generado anteriormente
  v_ind_ema VARCHAR2(1); --Debe generar el Email
  vno_envio VARCHAR2(4000);
  v_mensaje VARCHAR2(4000);
  v_error   EXCEPTION;
BEGIN
  BEGIN
    select automatico, ema_enviado, gen_mail
      into v_automat, v_ema_gen, v_ind_ema
      from cr_campanas
     where cod_campana = p_cod_campana;
  EXCEPTION
    when others then
      v_mensaje := 'ERROR. El codigo de campa풹 no existe';
      raise v_error;
  END;
  IF v_ema_gen = 'S' AND
     v_automat = 'N' THEN
    v_mensaje := 'ERROR. Los e-mails ya fueron generados anteriormente.';
    raise v_error;
  END IF;
  IF v_automat = 'S' THEN
    BEGIN
      update cr_campanas
         set ema_enviado = 'N'
       where cod_campana = p_cod_campana;
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudo inicializar la campa풹 actual '||sqlerrm;
        raise v_error;
    END;
  END IF;
  FOR x IN personas LOOP
    BEGIN
      it_mail.mail( fug_obt_dir_correo,
                    x.dir_correo,
                    x.ema_asunto,
                    x.ema_detalle );
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        IF vno_envio IS NOT NULL THEN
          vno_envio := vno_envio ||', ';
        ELSE
          vno_envio := 'No se pudo enviar email a las siguientes personas: ';
        END IF;
        if length(vno_envio) < 3900 then 
           vno_envio := vno_envio || x.cod_persona;
        end if;   
    END;
  END LOOP;
  IF vno_envio IS NOT NULL THEN
    v_mensaje := v_mensaje || vno_envio;
    raise v_error;
  END IF;
  BEGIN
    update cr_campanas
       set ema_enviado = 'S'
     where cod_campana = p_cod_campana;
  EXCEPTION
    when v_error then
      raise v_error;
    when others then
      v_mensaje := 'ERROR. No se pudo actualizar la campa풹 actual '||sqlerrm;
      raise v_error;
  END;
EXCEPTION
  when v_error then
    RAISE_APPLICATION_ERROR( -20000, v_mensaje );
  when others then
    RAISE_APPLICATION_ERROR( -20001, 'ERROR. En el proceso de envio de e-mails ' || sqlerrm||v_mensaje);
END pr_gen_email;
/* Genera las inibiciones y reabilitaciones de clientes */
PROCEDURE PR_GEN_INHIBICION
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 )
 IS
  CURSOR personas
      IS select p.cod_persona
           from cr_cam_personas p
          where p.cod_campana = p_cod_campana
            and p.cod_persona NOT IN( select cod_persona
                                        from ge_per_inhibidas
                                       where cod_persona = p.cod_persona
                                         and cod_campana = p.cod_campana
                                         and estado = 'I' )
          order by p.cod_persona;
  v_automat   VARCHAR2(1);
  v_inh_gen   VARCHAR2(1); --Inhibicion generada anteriormente
  v_ind_inh   VARCHAR2(1); --Debe generar la Inhibicion
  v_inh_det   VARCHAR2(2000);
  v_detalle   VARCHAR2(4000);
  v_fec_ini   DATE;
  v_fec_fin   DATE;
  v_cod_cau   NUMBER(3);
  v_origen    VARCHAR2(60);
  v_nro_ord   NUMBER;
  vfec_actual DATE := pae_cnf.fu_obt_fec_actual( 12 );
  pe          personas%rowtype;
  v_mensaje   VARCHAR2(500);
  v_error     EXCEPTION;
BEGIN
  BEGIN
    select automatico, inh_generada, gen_inhibicion, inh_detalle, fec_inicio, fec_vencimiento, inh_cod_causa,
           inh_origen
      into v_automat, v_inh_gen, v_ind_inh, v_inh_det, v_fec_ini, v_fec_fin, v_cod_cau, v_origen
      from cr_campanas
     where cod_campana = p_cod_campana;
  EXCEPTION
    when others then
      v_mensaje := 'ERROR. El codigo de campa풹 no existe ' || sqlerrm;
      raise v_error;
  END;
  IF v_inh_gen = 'S' AND
     v_automat = 'N' THEN
    v_mensaje := 'ERROR. La Inhibicion ya ha sido generada anteriormente';
    raise v_error;
  END IF;
  -- Verifica que sea automatica, si es asi inicializa el campo de Inhibicion generada, para tener
  -- un estado actual del proceso.
  IF v_automat = 'S' THEN
    BEGIN
      update cr_campanas
         set inh_generada = 'N'
       where cod_campana = p_cod_campana;
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudo inicializar la campa풹 actual '||sqlerrm;
        raise v_error;
    END;
    -- Rehabilita las Inhibiciones de Personas que ya no se encuentran en la Campa풹
    BEGIN
      update ge_per_inhibidas i
         set estado = 'D'
       where i.cod_campana = p_cod_campana
         and i.estado = 'I'
         and i.cod_persona NOT IN( select cod_persona
                                     from cr_cam_personas
                                    where cod_campana = i.cod_campana );
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. No se pudo actualizar las Rehabilitaciones de la campa풹 '||sqlerrm;
        raise v_error;
    END;
  END IF;
  FOR pe IN personas LOOP
    IF par_cam.fu_obt_cta_morosas( pe.cod_persona, vfec_actual ) IS NOT NULL THEN
      IF v_inh_det IS NOT NULL THEN
        v_detalle := v_inh_det || chr(10) || '   ---------' || chr(10);
      END IF;
      v_detalle := v_detalle || par_cam.fu_obt_cta_morosas( pe.cod_persona, vfec_actual );
      IF nvl( length( v_detalle ), 0 ) > 2000 THEN
        v_detalle := substr( v_detalle, 1, 1997 ) || '...';
      END IF;
    END IF;
    -- Busca el siguiente numero de orden para la persona
    BEGIN
      select nvl( max( nro_orden ), 0 ) + 1
        into v_nro_ord
        from ge_per_inhibidas
       where cod_persona = pe.cod_persona;
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'ERROR. Al buscar el siguiente nro. de orden para "' || pe.cod_persona || '"; ' || sqlerrm;
        raise v_error;
    END;
    BEGIN
	  v_fec_fin := v_fec_fin + fug_obt_parcausales( v_cod_cau, 'PLA_INHABILITACION' );
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_fec_fin := NULL;
    END;
    -- Inserta un registro de Inhibicion para la persona.
 	  BEGIN
 	    insert into ge_per_inhibidas( cod_persona,
                                    nro_orden,
                                    cod_causa,
                                    fec_inicio,
                                    fec_vencimiento,
                                    origen,
                                    detalle,
                                    usu_insercion,
                                    fec_insercion,
                                    estado,
                                    cod_campana )
                            values( pe.cod_persona,
                                    v_nro_ord,
                                    v_cod_cau,
                                    vfec_actual,
                                    v_fec_fin,
                                    v_origen,
                                    v_detalle,
                                    user,
                                    sysdate,
                                    'I',
                                    p_cod_campana );
 	  EXCEPTION
 	    when v_error then
 	      raise v_error;
 	    when others then
 	      v_mensaje := 'ERROR. No se pudo generar la Inhibicion ' || sqlerrm;
 	      raise v_error;
 	  END;
  END LOOP;
  BEGIN
    update cr_campanas
       set inh_generada = 'S'
     where cod_campana = p_cod_campana;
  EXCEPTION
    when v_error then
      raise v_error;
    when others then
      v_mensaje := 'ERROR. No se pudo actualizar la campa풹 actual '||sqlerrm;
      raise v_error;
  END;
EXCEPTION
  when v_error then
    RAISE_APPLICATION_ERROR(-20000, v_mensaje );
  when others then
    RAISE_APPLICATION_ERROR(-20000, 'ERROR. en p_genera_agenda '||sqlerrm);
END;
/* Proceso autom. qu realizas las operaciones relacionadas con la campa풹 */
PROCEDURE PR_PRO_AUTOMATICO(p_cod_campana in number default null)
 IS
  vfec_actual DATE := pae_cnf.fu_obt_fec_actual( 12 );
  CURSOR campanas( p_automatico VARCHAR2 )
      IS select *
           from cr_campanas
          where vfec_actual between fec_inicio and nvl( fec_vencimiento, to_date( '31/12/9999', 'DD/MM/YYYY' ) )
            and nvl( automatico, 'N' ) = p_automatico
            and nvl( estado, 1 ) = 2
            and (cod_campana = p_cod_campana or p_cod_campana is null)
          order by cod_campana;
BEGIN
  -- Procesa las campa풹s automaticas
  FOR ca IN campanas( 'S' ) LOOP
    -- Procesos de inicializacion
    par_cam.pr_gen_his_campanas( ca.cod_campana );
    par_cam.pr_gen_cam_personas( ca.cod_campana );
    -- Regenera la agenda
    IF nvl( ca.gen_agenda, 'N' ) = 'S' THEN
      par_cam.pr_gen_agenda( ca.cod_campana );
    END IF;
    -- Regenera las notas
    IF nvl( ca.gen_nota, 'N' ) = 'S' THEN
      par_cam.pr_gen_nota( ca.cod_campana );
    END IF;
    -- Regenera los e-mails
    IF nvl( ca.gen_mail, 'N' ) = 'S' THEN
      par_cam.pr_gen_email( ca.cod_campana );
    END IF;
    -- Genera las inhibiciones
    IF nvl( ca.gen_inhibicion, 'N' ) = 'S' THEN
      par_cam.pr_gen_inhibicion( ca.cod_campana );
    END IF;
  END LOOP;
  par_cam.pr_cam_vencida;
EXCEPTION
  when others then
    IF sqlcode <= -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR( -20000, 'ERROR. Proceso automatico de campa풹s ' || sqlerrm );
    END IF;
END;
/* Proceso de actualizacion de actividades efectivizadas */
PROCEDURE PR_PRO_ACT_EFECTIVAS
 IS
  vfec_actual DATE := pae_cnf.fu_obt_fec_actual( 12 );
  vmensaje    VARCHAR2(1000);
  verror      EXCEPTION;
  CURSOR campanas
      IS select c.cod_campana, p.cod_modulo, p.cod_modalidad, p.cod_moneda
           from cr_campanas c, cr_cam_productos p
          where vfec_actual between fec_inicio and nvl( fec_vencimiento, to_date( '31/12/9999', 'DD/MM/YYYY' ) )
            and c.cod_campana = p.cod_campana
            and nvl( c.estado, 1 ) = 2
          order by cod_campana;
BEGIN
  FOR m IN campanas LOOP
    BEGIN
      update cr_cam_personas p
         set p.estado = '4'
       where p.cod_campana = m.cod_campana
         and p.estado <> '4'
         and p.cod_persona IN( select t.cod_persona
                                 from ge_cta_clientes t, ge_cuentas u, ge_est_cuentas e
                                where t.cod_persona = p.cod_persona
                                  and t.cod_modulo = m.cod_modulo
                                  and t.cod_modalidad = m.cod_modalidad
                                  and t.relacion IN( 'P' )
                                  and t.nro_cuenta = u.nro_cuenta
                                  and t.cod_modulo = u.cod_modulo
                                  and t.cod_modalidad = u.cod_modalidad
                                  and m.cod_moneda = u.cod_moneda
                                  and e.cod_modulo = u.cod_modulo
                                  and e.cod_modalidad = u.cod_modalidad
                                  and e.estado = u.estado
                                  and nvl( e.activo, 'N' ) = 'S' );
    EXCEPTION
      when others then
        vmensaje := 'ERROR. Al actualizar el estado de las personas asociadas a la campa풹 ' || sqlerrm;
        raise verror;
    END;
  END LOOP;
  par_cam.pr_cam_vencida;
EXCEPTION
  when verror then
    RAISE_APPLICATION_ERROR( -20000, vmensaje );
  when others then
    IF sqlcode <= -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR( -20000, 'ERROR. En el proceso de actualizacion de estados ' || sqlerrm );
    END IF;
END;
/* Proceso de control de actividades de cobranzas */
PROCEDURE PR_GEN_ACT_COBRANZA
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE
 ) IS
  /*
  || EFECTUA      : Proceso encargado de mantener el detalle de cuentas relacionadas a la
  ||                agenda de Cobranzas generadas por cada usuario gestor.
  || DEPENDENCIAS : Parametros: * DIA_ATR_INI_AGENDA
  ||                            * DIA_ATR_FIN_AGENDA
  || HISTORIA     : 28/10/2005 | PPalella     | Creacion del proceso
  ||                13/12/2005 | PPalella     | Redefinicion del proceso
  ||                           |              |
  */
  v_dia_atr_ini  CONSTANT NUMBER(10) := to_number( substr( fug_obt_pardinamico( 'DIA_ATR_INI_AGENDA' ), 1, 10 ) );
  v_dia_atr_fin  CONSTANT NUMBER(10) := to_number( substr( fug_obt_pardinamico( 'DIA_ATR_FIN_AGENDA' ), 1, 10 ) );
  v_fec_prestamo CONSTANT date := pag_cal.fu_obt_fec_actual(6);
  v_act_cobranza CONSTANT VARCHAR2(20) := fug_obt_pardinamico( 'COD_ACT_COBRANZA' );
  v_existe       VARCHAR2(1) := 'N';
  v_mensaje      VARCHAR2(2000);
  v_error        EXCEPTION;
  CURSOR detalle
      IS select cp.cod_persona, ct.nro_cuenta, cu.nro_cuota, ct.cod_modulo, ct.cod_modalidad, ct.cod_moneda,
                cu.fec_vencimiento, ct.dia_atraso,
                --ct.mto_mora mto_atraso,
                ( nvl( cu.sal_capital, 0 ) + nvl( cu.sal_interes, 0 ) + nvl( cu.sal_int_documentado, 0 ) ) mto_atraso,
                ag.cod_agenda, ag.fec_ini_asignacion,
                ag.cod_estado, ag.cod_usu_encargado cod_usu_responsable
           from cr_cam_personas cp, cr_agendas ag, cr_age_est_actividades ea, ge_cta_clientes cc,
                pr_cta_prestamos ct, ge_est_cuentas ec, pr_cuotas cu
          where cp.cod_campana = p_cod_campana
            and cp.cod_campana = ag.cod_campana
            and cp.cod_persona = ag.cod_persona
            and v_act_cobranza = ag.cod_actividad
            and ea.cod_actividad = ag.cod_actividad
            and ea.cod_estado = ag.cod_estado
            and nvl( ea.grupo, 'x' ) = 'P'
            and nvl( ea.ind_reprogramacion, 'N' ) <> 'S'
            and nvl( ea.ind_reasignacion, 'N' ) <> 'S'
            and nvl( ea.ind_cancelacion, 'N' ) <> 'S'
            and ag.cod_agenda = ( select max( cod_agenda )
                                    from cr_agendas ad, cr_age_est_actividades et
                                   where ad.cod_campana = ag.cod_campana
                                     and ad.cod_persona = ag.cod_persona
                                     and ad.cod_actividad = ag.cod_actividad
                                     and ad.cod_actividad = et.cod_actividad
                                     and ad.cod_estado = et.cod_estado
                                     and nvl( et.grupo, 'x' ) = 'P'
                                     and nvl( et.ind_reprogramacion, 'N' ) <> 'S'
                                     and nvl( et.ind_reasignacion, 'N' ) <> 'S'
                                     and nvl( et.ind_cancelacion, 'N' ) <> 'S' )
            and cp.cod_persona = cc.cod_persona
            and cc.relacion = 'P'
            and nvl( ct.en_juicio, 'N' ) = 'N'
            and nvl( ct.dia_atraso, 0 ) between v_dia_atr_ini and v_dia_atr_fin
            -- Esto es para que inserte solo las cuotas que tienen entre V_DIA_ATR_INI y V_DIA_ATR_FIN dias de mora
            and ( v_fec_prestamo - cu.fec_vencimiento ) between v_dia_atr_ini and v_dia_atr_fin
            and ct.cod_banca <> 1
            and ct.nro_cuenta = cc.nro_cuenta
            and ct.cod_modulo = ec.cod_modulo
            and ct.cod_modalidad = ec.cod_modalidad
            and ct.estado = ec.estado
            and nvl( ec.activo, 'N' ) = 'S'
            and ct.nro_cuenta = cu.nro_cuenta
            and cu.nro_cuota > 0
            and nvl( cu.estado, 'x' ) <> 'N'
            and cu.fec_vencimiento <= v_fec_prestamo
       UNION ALL
         select cp.cod_persona, ct.nro_cuenta, to_number( to_char( sc.fec_cierre, 'YMM' ) ) nro_cuota,
                ct.cod_modulo, ct.cod_modalidad, ct.cod_moneda,
                sc.fec_vto_pago fec_vencimiento, ct.dia_mora dia_atraso, ct.mto_mora mto_atraso, ag.cod_agenda,
                ag.fec_ini_asignacion, ag.cod_estado, ag.cod_usu_encargado cod_usu_responsable
           from cr_cam_personas cp, cr_agendas ag, cr_age_est_actividades ea, ge_cta_clientes cc,
                ta_cta_tarjetas ct, ge_est_cuentas ec, ta_sal_cierres sc
          where cp.cod_campana = p_cod_campana
            and cp.cod_campana = ag.cod_campana
            and cp.cod_persona = ag.cod_persona
            and v_act_cobranza = ag.cod_actividad
            and ea.cod_actividad = ag.cod_actividad
            and ea.cod_estado = ag.cod_estado
            and nvl( ea.grupo, 'x' ) = 'P'
            and nvl( ea.ind_reprogramacion, 'N' ) <> 'S'
            and nvl( ea.ind_reasignacion, 'N' ) <> 'S'
            and nvl( ea.ind_cancelacion, 'N' ) <> 'S'
            and ag.cod_agenda = ( select max( cod_agenda )
                                    from cr_agendas ad, cr_age_est_actividades et
                                   where ad.cod_campana = ag.cod_campana
                                     and ad.cod_persona = ag.cod_persona
                                     and ad.cod_actividad = ag.cod_actividad
                                     and ad.cod_actividad = et.cod_actividad
                                     and ad.cod_estado = et.cod_estado
                                     and nvl( et.grupo, 'x' ) = 'P'
                                     and nvl( et.ind_reprogramacion, 'N' ) <> 'S'
                                     and nvl( et.ind_reasignacion, 'N' ) <> 'S'
                                     and nvl( et.ind_cancelacion, 'N' ) <> 'S' )
            and cp.cod_persona = cc.cod_persona
            and cc.relacion = 'P'
            and nvl( ct.en_juicio, 'N' ) = 'N'
            and nvl( ct.dia_mora, 0 ) between v_dia_atr_ini and v_dia_atr_fin
            and ct.nro_cuenta = cc.nro_cuenta
            and ct.cod_modulo = ec.cod_modulo
            and ct.cod_modalidad = ec.cod_modalidad
            and ct.estado = ec.estado
            and nvl( ec.activo, 'N' ) = 'S'
            and sc.nro_cuenta = ct.nro_cuenta
            and sc.fec_cierre = ( select max( tc.fec_cierre )
                                    from ta_sal_cierres tc
                                   where tc.nro_cuenta = sc.nro_cuenta )
          order by 1, -- cp.cod_persona
                   9, -- ag.cod_agenda
                   2; -- ct.nro_cuenta
BEGIN
  FOR x IN detalle LOOP
    BEGIN
      select 'S'
        into v_existe
        from co_actividades
       where nro_cuenta = x.nro_cuenta
         and nro_cuota = x.nro_cuota
         and cod_campana = p_cod_campana;
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_existe := 'N';
    END;
    IF v_existe = 'S' THEN
      BEGIN
        update co_actividades
           set dia_atraso          = x.dia_atraso,
---               mto_atraso          = decode( x.cod_modulo, 6, x.mto_atraso, 5, mto_atraso ),
               cod_agenda          = x.cod_agenda,
---               fec_ini_asignacion  = x.fec_ini_asignacion,
               cod_est_agenda      = x.cod_estado,
               cod_usu_responsable = x.cod_usu_responsable
         where cod_campana = p_cod_campana
           and cod_persona = x.cod_persona
           and nro_cuenta = x.nro_cuenta
           and nro_cuota = x.nro_cuota
           and fec_vencimiento = x.fec_vencimiento;
      EXCEPTION
        when v_error then
          raise v_error;
        when others then
          v_mensaje := 'No se pudo actualizar la actividad: CAM:' || to_char( p_cod_campana ) ||
                       ' PER: ' || x.cod_persona || ' CTA: ' || x.nro_cuenta || ' CUO: ' || to_char( x.nro_cuota ) ||
                       ' VEN: ' || to_char( x.fec_vencimiento, 'DD/MM/YY' ) || '; ' || sqlerrm;
          raise v_error;
      END;
    ELSE
      BEGIN
        insert into co_actividades( cod_campana,
                                    cod_persona,
                                    nro_cuenta,
                                    nro_cuota,
                                    cod_modulo,
                                    cod_modalidad,
                                    cod_moneda,
                                    fec_vencimiento,
                                    dia_atraso,
                                    mto_atraso,
                                    cod_agenda,
                                    fec_ini_asignacion,
                                    cod_est_agenda,
                                    cod_usu_responsable )
                            values( p_cod_campana,
                                    x.cod_persona,
                                    x.nro_cuenta,
                                    x.nro_cuota,
                                    x.cod_modulo,
                                    x.cod_modalidad,
                                    x.cod_moneda,
                                    x.fec_vencimiento,
                                    x.dia_atraso,
                                    x.mto_atraso,
                                    x.cod_agenda,
                                    x.fec_ini_asignacion,
                                    x.cod_estado,
                                    x.cod_usu_responsable );
      EXCEPTION
        when v_error then
          raise v_error;
        when others then
          v_mensaje := 'No se pudo insertar la actividad: CAM:' || to_char( p_cod_campana ) ||
                       ' PER: ' || x.cod_persona || ' CTA: ' || x.nro_cuenta || ' CUO: ' || to_char( x.nro_cuota ) ||
                       ' VEN: ' || to_char( x.fec_vencimiento, 'DD/MM/YY' ) || '; ' || sqlerrm;
          raise v_error;
      END;
    END IF;
  END LOOP;
EXCEPTION
  when v_error then
    RAISE_APPLICATION_ERROR( -20852, v_mensaje );
  when others then
    RAISE_APPLICATION_ERROR( -20853, 'Error en el proceso de control de actividades de cobranzas ' || sqlerrm );
END PR_GEN_ACT_COBRANZA;
/* Proceso de control y correccion de datos del cobro */
PROCEDURE PR_CTL_PAG_COBRANZA
 (P_COD_CAMPANA CR_CAMPANAS.COD_CAMPANA%TYPE DEFAULT NULL
 ) IS
  /*
  || EFECTUA      : Proceso encargado de controlar y corregir los datos de los cobros
                    relacionados a las actividades de cobranzas.
  || DEPENDENCIAS : Parametro: * COD_ACT_COBRANZA
  || HISTORIA     : 14/12/2005 | PPalella     | Creacion del proceso
  ||                           |              |
  */
  v_act_cobranza CONSTANT VARCHAR2(20) := fug_obt_pardinamico( 'COD_ACT_COBRANZA' );
  v_ult_fecha    CO_ACTIVIDADES.FEC_ULT_COBRO%TYPE;
  v_ult_atraso   CO_ACTIVIDADES.DIA_ATR_ULT_COBRO%TYPE;
  CURSOR campanas
      IS select cod_campana
           from cr_campanas
          where cod_campana = nvl( p_cod_campana, cod_campana )
            and estado = 2
            and nvl( age_generada, 'N' ) = 'S'
            and cod_actividad = v_act_cobranza
          order by cod_campana;
  CURSOR cuentas( p_campana VARCHAR2 )
      IS select nro_cuenta, nro_cuota
           from co_actividades
          where cod_campana = p_campana
            and cod_modulo = 6
            and nvl( mto_acu_cobrado, 0 ) <> 0
            and ( fec_ult_cobro IS NULL OR dia_atr_ult_cobro IS NULL )
          order by nro_cuenta, nro_cuota;
BEGIN
  FOR p IN campanas LOOP
    FOR c IN cuentas( p.cod_campana ) LOOP
      BEGIN
        select a.fecha, a.dia_mora
          into v_ult_fecha, v_ult_atraso
          from pr_cobros a
         where a.nro_cuenta = c.nro_cuenta
           and a.nro_cuota = c.nro_cuota
           and to_date( to_char( a.fecha, 'DD/MM/YYYY' ) || a.hora, 'DD/MM/YYYY HH24:MI:SS' ) =
               ( select max( to_date( to_char( b.fecha, 'DD/MM/YYYY' ) || b.hora, 'DD/MM/YYYY HH24:MI:SS' ) )
                   from pr_cobros b
                  where b.nro_cuenta = a.nro_cuenta
                    and b.nro_cuota = a.nro_cuota );
      EXCEPTION
        when no_data_found then
          v_ult_fecha := NULL;
          v_ult_atraso := NULL;
        when others then
          v_ult_fecha := NULL;
          v_ult_atraso := NULL;
          RAISE_APPLICATION_ERROR( -20287, 'Error al buscar la fecha de ultimo cobro de la cuenta ' || c.nro_cuenta ||
                                           '/' || c.nro_cuota || '; ' || sqlerrm );
      END;
      BEGIN
        update co_actividades
           set fec_ult_cobro = v_ult_fecha,
               dia_atr_ult_cobro = v_ult_atraso
         where cod_campana = p.cod_campana
           and nro_cuenta = c.nro_cuenta
           and nro_cuota = c.nro_cuota;
      EXCEPTION
        when others then
          IF sqlcode < -20000 THEN
            raise;
          ELSE
            RAISE_APPLICATION_ERROR( -20287, 'Error al actualizar los datos de la cuenta ' || c.nro_cuenta ||
                                             '/' || c.nro_cuota || '; ' || sqlerrm );
          END IF;
      END;
    END LOOP;
  END LOOP;
END PR_CTL_PAG_COBRANZA;
/* Proceso de actualizacion de pagos para actividades de cobranzas */
PROCEDURE PR_ACT_PAG_COBRANZA
 (P_NRO_CUENTA  GE_CUENTAS.NRO_CUENTA%TYPE,
  P_NRO_CUOTA   PR_CUOTAS.NRO_CUOTA%TYPE,
  P_FEC_COBRO   DATE,
  P_DIA_ATRASO  GE_CUENTAS.DIA_ATRASO%TYPE,
  P_MTO_COBRADO TA_COBROS.MONTO%TYPE
 ) IS
  /*
  || EFECTUA      : Proceso encargado de actualizar los datos relacionados al cobro de cuentas, en
                    la tabla de actividades (CO_ACTIVIDADES)
  || DEPENDENCIAS : (null)
  || HISTORIA     : 14/12/2005 | PPalella     | Creacion del proceso
  ||                           |              |
  */
  v_cod_persona BA_PERSONAS.COD_PERSONA%TYPE;
  v_cod_modulo  BA_MODULOS.COD_MODULO%TYPE;
  v_cuo_tarjeta CO_ACTIVIDADES.NRO_CUOTA%TYPE;
  v_ult_cuo_tar CO_ACTIVIDADES.NRO_CUOTA%TYPE;
  v_mensaje     VARCHAR2(2000);
  v_error       EXCEPTION;
BEGIN
  BEGIN
    select g.cod_modulo, c.cod_persona
      into v_cod_modulo, v_cod_persona
      from ge_cuentas g, ge_cta_clientes c
     where g.nro_cuenta = p_nro_cuenta
       and g.nro_cuenta = c.nro_cuenta
       and nvl( c.relacion, 'x' ) = 'P';
  EXCEPTION
    when others then
      v_mensaje := 'Error al recuperar los datos de la cuenta ' || p_nro_cuenta || '; ' || sqlerrm;
      raise v_error;
  END;
  IF v_cod_modulo = 5 THEN
    /*
    || Si es un pago de tarjetas, busca el registro del ultimo extracto
    || y verifica que no exista un cierre posterior al ultimo extracto con mora,
    || si el ultimo extracto es el mismo que esta en mora, le suma a ese valor, de lo
    || contrario, no hace nada.
    */
    BEGIN
      select max( nro_cuota )
        into v_cuo_tarjeta
        from co_actividades
       where nro_cuenta = p_nro_cuenta
         and cod_persona = v_cod_persona;
    EXCEPTION
      when others then
        v_cuo_tarjeta := to_number( to_char( p_fec_cobro, 'YMM' ) );
    END;
    BEGIN
      select to_number( to_char( max( fec_cierre ), 'YMM' ) )
        into v_ult_cuo_tar
        from ta_sal_cierres
       where nro_cuenta = p_nro_cuenta;
    EXCEPTION
      when others then
        v_ult_cuo_tar := to_number( to_char( p_fec_cobro, 'YMM' ) );
    END;
    IF v_cuo_tarjeta = v_ult_cuo_tar THEN
      BEGIN
        update co_actividades a
           set a.fec_ult_cobro = p_fec_cobro,
               a.dia_atr_ult_cobro = p_dia_atraso,
               a.mto_acu_cobrado = nvl( a.mto_acu_cobrado, 0 ) + nvl( p_mto_cobrado, 0 )
         where a.nro_cuenta = p_nro_cuenta
           and a.nro_cuota = v_cuo_tarjeta
           and a.cod_persona = v_cod_persona;
      EXCEPTION
        when v_error then
          raise v_error;
        when others then
          v_mensaje := 'Error al actualizar la los datos para la cuenta de prestamo ' || p_nro_cuenta || '; ' || sqlerrm;
          raise v_error;
      END;
    END IF;
  ELSIF v_cod_modulo = 6 THEN
    -- Si es un pago de prestamo, busca directamente por el numero de cuota.
    BEGIN
      update co_actividades
         set fec_ult_cobro = nvl( p_fec_cobro, fec_ult_cobro ),
             dia_atr_ult_cobro = nvl( p_dia_atraso, dia_atr_ult_cobro ),
             mto_acu_cobrado = nvl( mto_acu_cobrado, 0 ) + nvl( p_mto_cobrado, 0 )
       where nro_cuenta = p_nro_cuenta
         and nro_cuota = p_nro_cuota
         and cod_persona = v_cod_persona;
    EXCEPTION
      when v_error then
        raise v_error;
      when others then
        v_mensaje := 'Error al actualizar la los datos para la cuenta de prestamo ' || p_nro_cuenta || '; ' || sqlerrm;
        raise v_error;
    END;
  END IF;
EXCEPTION
  when v_error then
    RAISE_APPLICATION_ERROR( -20251, 'PAR_CAM.PR_ACT_PAG_COBRANZA: ' || v_mensaje );
  when others then
    RAISE_APPLICATION_ERROR( -20251, 'PAR_CAM.PR_ACT_PAG_COBRANZA: Error inesperado ' || sqlerrm );
END PR_ACT_PAG_COBRANZA;
END PAR_CAM;
/

