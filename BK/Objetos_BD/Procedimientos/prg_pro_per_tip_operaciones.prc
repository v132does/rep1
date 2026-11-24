CREATE OR REPLACE PROCEDURE IT.prg_pro_per_tip_operaciones IS
  v_existe   VARCHAR2(1) := 'N';
  v_cantidad NUMBER;
  CURSOR c_operaciones IS
    SELECT t.cod_persona,
           t.cod_moneda,
           t.mto_limite,
           t.fec_inicio,
           t.fec_vencimiento,
           t.tip_ope_otros,
           t.procesado,
           fon_propio, fon_salario,fon_prestamos, fon_vta_activos, fon_ren_financieras,
           fon_ahorro, fon_herencia, fon_transferencias, 
           fon_otros, pro_ingresos, pro_ahorros, pro_ven_alq, 
           pro_gas_operativos, pro_otros
      FROM cr_per_tip_operaciones_tmp t
     WHERE nvl(t.procesado, 'N') = 'N';
BEGIN
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
  FOR r_cup IN c_operaciones LOOP
    --verificar si existe la misma operación antes de insertar
    BEGIN
      SELECT DISTINCT ('S'), COUNT(1)
        INTO v_existe, v_cantidad
        FROM cr_per_tip_operaciones t
       WHERE t.cod_persona = r_cup.cod_persona
       GROUP BY cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        v_existe := 'N';
    END;
    IF v_existe = 'N' THEN
      BEGIN
        INSERT INTO cr_per_tip_operaciones
          (cod_persona,
           cod_moneda,
           mto_limite,
           fec_inicio,
           fec_vencimiento)
        VALUES
          (r_cup.cod_persona,
           r_cup.cod_moneda,
           r_cup.mto_limite,
           r_cup.fec_inicio,
           r_cup.fec_vencimiento);
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,'Error al insert CR_PER_TIP_OPERACIONES ' ||SQLERRM);
      END;
    ELSIF v_existe = 'S' AND
          v_cantidad = 1 THEN
      BEGIN
        UPDATE cr_per_tip_operaciones j
           SET j.mto_limite      = r_cup.mto_limite,
               j.fec_inicio      = r_cup.fec_inicio,
               j.fec_vencimiento = r_cup.fec_vencimiento
         WHERE j.cod_persona = r_cup.cod_persona
           AND j.cod_moneda = r_cup.cod_moneda;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20001,'Error al actualizar CR_PER_TIP_OPERACIONES ' ||SQLERRM);
      END;
    ELSE
      raise_application_error(-20002,'Error: Persona ' || r_cup.cod_persona ||' con más de un Perfil.');
    END IF;
    ------ limpio variable
    v_existe := 'N';

    --verificar si existe la misma operación antes de insertar en cr_inf_fondos
    BEGIN
      SELECT DISTINCT ('S')
        INTO v_existe
        FROM cr_inf_fondos t
       WHERE t.cod_persona = r_cup.cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        v_existe := 'N';
    END;
    BEGIN
      IF v_existe = 'N' THEN
        INSERT INTO cr_inf_fondos
          (cod_persona, tip_ope_otros, fon_propio, fon_salario,
           fon_prestamos, fon_vta_activos, fon_ren_financieras,
           fon_ahorro, fon_herencia, fon_transferencias, 
           fon_otros, pro_ingresos, pro_ahorros, pro_ven_alq, 
           pro_gas_operativos, pro_otros)
        VALUES
          (r_cup.cod_persona, r_cup.tip_ope_otros, nvl(r_cup.fon_propio,'N'), nvl(r_cup.fon_salario,'N'),
           nvl(r_cup.fon_prestamos,'N'), nvl(r_cup.fon_vta_activos,'N'), nvl(r_cup.fon_ren_financieras,'N'),
           nvl(r_cup.fon_ahorro,'N'), nvl(r_cup.fon_herencia,'N'), nvl(r_cup.fon_transferencias,'N'), 
           r_cup.fon_otros, nvl(r_cup.pro_ingresos,'N'), nvl(r_cup.pro_ahorros,'N'), nvl(r_cup.pro_ven_alq,'N'), 
           nvl(r_cup.pro_gas_operativos,'N'), r_cup.pro_otros);
      ELSE
        UPDATE cr_inf_fondos j
           SET j.tip_ope_otros = r_cup.tip_ope_otros,
               j.fon_propio    = nvl(r_cup.fon_propio,'N'),
               j.fon_salario   = nvl(r_cup.fon_salario,'N'),
               j.fon_prestamos = nvl(r_cup.fon_prestamos,'N'),
               j.fon_vta_activos =  nvl(r_cup.fon_vta_activos,'N'),
               j.fon_ren_financieras = nvl(r_cup.fon_ren_financieras,'N'),
               j.fon_ahorro   = nvl(r_cup.fon_ahorro,'N'),
               j.fon_herencia = nvl(r_cup.fon_herencia,'N'), 
               j.fon_transferencias = nvl(r_cup.fon_transferencias,'N'), 
               j.fon_otros = r_cup.fon_otros, 
               j.pro_ingresos = nvl(r_cup.pro_ingresos,'N'), 
               j.pro_ahorros  = nvl(r_cup.pro_ahorros,'N'),
               j.pro_ven_alq  = nvl(r_cup.pro_ven_alq,'N'),
               j.pro_gas_operativos = nvl(r_cup.pro_gas_operativos,'N'),  
               j.pro_otros  =  r_cup.pro_otros
         WHERE j.cod_persona = r_cup.cod_persona;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,'Error insert/actualizar cr_inf_fondos ' ||SQLERRM);
    END;
    -------
    BEGIN
      UPDATE cr_per_tip_operaciones_tmp j
         SET j.procesado = 'S',
             j.fecha = SYSDATE
       WHERE j.cod_persona = r_cup.cod_persona
         AND j.cod_moneda = r_cup.cod_moneda
         AND j.mto_limite = r_cup.mto_limite
         AND j.fec_inicio = r_cup.fec_inicio
         AND j.fec_vencimiento = r_cup.fec_vencimiento
         AND j.tip_ope_otros = r_cup.tip_ope_otros;
    END;
  END LOOP;
  
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error prg_pro_per_tip_operaciones. ' ||SQLERRM);
END;
/
