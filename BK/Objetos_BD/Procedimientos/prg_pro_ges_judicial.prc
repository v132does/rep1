CREATE OR REPLACE PROCEDURE IT.PRG_PRO_GES_JUDICIAL
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_EN_JUICIO IN GE_CUENTAS.EN_JUICIO%TYPE
 ,P_COD_ENTE IN NUMBER := NULL
 )
 IS
  vmodulo     NUMBER(3);
  vmodalidad  NUMBER(3);
  vjuicio     VARCHAR2(1);
  vente       NUMBER(5);
  vfecha      DATE;
  vent_juicio NUMBER(5);
  vmensaje    VARCHAR2(2000);
  no_procesa  EXCEPTION;
  verror      EXCEPTION;
BEGIN
  BEGIN
    select cod_modulo, cod_modalidad, en_juicio, cod_ent_juicio
      into vmodulo, vmodalidad, vjuicio, vente
      from ge_cuentas
     where nro_cuenta = p_nro_cuenta;
  EXCEPTION
    when others then
      vmensaje := 'No se pudo obtener los datos de la cuenta ' || p_nro_cuenta  || '; ' || sqlerrm;
      raise verror;
  END;
  IF p_en_juicio IS NULL THEN
    vmensaje := 'No se definió el valor para el parámetro P_EN_JUICIO.';
    raise verror;
  END IF;
  IF p_en_juicio = 'S' THEN
    IF p_cod_ente IS NULL THEN
      vmensaje := 'No se definió el Estudio Jurídico al cual derivar las cuenta.';
      raise verror;
    END IF;
    IF vjuicio = 'S' AND
       p_cod_ente = vente THEN
      raise no_procesa;
    END IF;
    vfecha := pag_cal.fu_obt_fec_actual( vmodulo );
    vent_juicio := p_cod_ente;
  END IF;
  IF p_en_juicio = 'N' THEN
    IF vjuicio = 'N' THEN
      raise no_procesa;
    END IF;
    vfecha := NULL;
    vent_juicio := NULL;
  END IF;
  IF vmodulo = 3 THEN     -- Cuenta de AHORROS
    vmensaje := 'No se puede pasar a Gestión Judicial una cuenta de Ahorros.';
    raise verror;
  ELSIF vmodulo = 4 THEN  -- Cuenta CURRIENTE
    BEGIN
      update cc_cta_corrientes
         set en_juicio = p_en_juicio,
             fec_juicio = vfecha,
             cod_ent_juicio = vent_juicio
       where nro_cuenta = p_nro_cuenta;
    EXCEPTION
      when verror then
        raise verror;
      when no_procesa then
        raise no_procesa;
      when others then
        vmensaje := 'No se pudo actualizar la Cuenta Corriente ' || p_nro_cuenta  || '; ' || sqlerrm;
        raise verror;
    END;
  ELSIF vmodulo = 5 THEN  -- Cuenta de TARJETAS
    BEGIN
      update ta_cta_tarjetas
         set en_juicio = p_en_juicio,
             fec_juicio = vfecha,
             cod_ent_juicio = vent_juicio
       where nro_cuenta = p_nro_cuenta;
    EXCEPTION
      when verror then
        raise verror;
      when no_procesa then
        raise no_procesa;
      when others then
        vmensaje := 'No se pudo actualizar la cuenta de la Tarjeta ' ||  p_nro_cuenta  || '; ' || sqlerrm;
        raise verror;
    END;
  ELSIF vmodulo = 6 THEN  -- Cuenta de PRESTAMOS
    BEGIN
      update pr_cta_prestamos
         set en_juicio = p_en_juicio,
             fec_juicio = vfecha,
             cod_ent_juicio = vent_juicio
       where nro_cuenta = p_nro_cuenta;
    EXCEPTION
      when verror then
        raise verror;
      when no_procesa then
        raise no_procesa;
      when others then
        vmensaje := 'No se pudo actualizar la cuenta de Préstamo ' ||  p_nro_cuenta  || '; ' || sqlerrm;
        raise verror;
    END;
  END IF;
  IF vmodulo IN (4,5,6) THEN
    BEGIN
    UPDATE ge_cuentas
    SET en_juicio = p_en_juicio,
        fec_juicio = vfecha,
        cod_ent_juicio = vent_juicio
    WHERE nro_cuenta = p_nro_cuenta;
    EXCEPTION
    when others then
        vmensaje := 'No se pudo actualizar la cuenta ' ||  p_nro_cuenta  || '; ' || sqlerrm;
        raise verror;
    END;
  END IF;
EXCEPTION
  when verror then
    RAISE_APPLICATION_ERROR( -20000, 'Pro_Ges_Jud: ' || vmensaje );
  when no_procesa then
    NULL;
  when others then
    RAISE_APPLICATION_ERROR( -20000, 'Pro_Ges_Jud: ' || sqlerrm );
END;

 