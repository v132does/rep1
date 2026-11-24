CREATE OR REPLACE PACKAGE BODY IT.par_per IS
 --------------------------------------------------
  ---Funcion Principal
  FUNCTION fu_val_dat_personas(p_cod_persona    IN ba_personas.cod_persona%TYPE,
                               p_cod_modulo     IN ba_modulos.cod_modulo%TYPE,
                               p_cod_modalidad  IN ge_modalidades.cod_modalidad%TYPE,
                               p_mto_solicitud  IN pr_solicitudes.monto%TYPE,
                               p_ind_evaluacion IN pr_solicitudes.ind_evaluacion%type default 'S')
    RETURN BOOLEAN IS
    v_tipo            ba_personas.tipo%TYPE;
    v_control         NUMBER := 0;
    v_ret_fisicas     BOOLEAN := TRUE;
    v_ret_laborales   BOOLEAN := TRUE;
    v_ret_financieros BOOLEAN := TRUE;
    v_ret_propiedades BOOLEAN := TRUE;
    v_ret_patrimonios BOOLEAN := TRUE;
    v_ret_personas    BOOLEAN := TRUE;
    v_ret_principal   BOOLEAN := TRUE;
    v_par_dinamico    VARCHAR2(1) := 'N';
  BEGIN
    IF p_cod_persona IS NULL THEN
      pr_err_mensajes('Código de Persona es requerido.');
    END IF;
    IF p_cod_modulo IS NULL THEN
      pr_err_mensajes('Código de Módulo es requerido.');
    END IF;
    IF p_cod_modalidad IS NULL THEN
      pr_err_mensajes('Código de Modalidad es requerido.');
    END IF;
    IF p_mto_solicitud IS NULL THEN
      pr_err_mensajes('Monto de solicitud es requerido.');
    END IF;
    --Inicializo variables globales
    g_cod_persona   := p_cod_persona;
    g_cod_modulo    := p_cod_modulo;
    g_cod_modalidad := p_cod_modalidad;
    g_mto_solicitud := p_mto_solicitud;
    --Verifico que la persona sea de Tipo Física
    BEGIN
      SELECT a.tipo
        INTO v_tipo
        FROM ba_personas a
       WHERE a.cod_persona = g_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('Persona no definida en (BA_PERSONAS).');
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (BA_PERSONAS). ' || SQLERRM);
    END;
    --Realizo la Verificación sólo si es Persona Tipo Fisica
    IF v_tipo = 'F' THEN
      --Verifico el Módulo
      SELECT COUNT(1)
        INTO v_control
        FROM ba_modulos a
       WHERE a.cod_modulo = g_cod_modulo;
      IF v_control = 0 THEN
        pr_err_mensajes('Módulo no definido en (BA_MODULOS).');
      END IF;
      --Verifico la Modalidad
      SELECT COUNT(1)
        INTO v_control
        FROM ge_modalidades a
       WHERE a.cod_modulo = g_cod_modulo
         AND a.cod_modalidad = g_cod_modalidad;
      IF v_control = 0 THEN
        pr_err_mensajes('Modalidad no definida en (GE_MODALIDADES) o no corresponde al Módulo.');
      END IF;
      --Verifico Parámetro Dinámico de Modalidades Definidas para el control.
      v_par_dinamico := nvl(fug_obt_pardinamico('SOL_MAD_VERIFICACIONES',
                                                g_cod_modulo,
                                                g_cod_modalidad),
                            'N');
      --Realizo la Verificación sólo para los Módulos y Modalidades definidas.
      IF v_par_dinamico = 'S' THEN
         IF p_ind_evaluacion = 'S' THEN
            --Borro la verificación anterior de la persona
            DELETE FROM ge_sol_ver_personas_det_tmp a
             WHERE a.cod_persona = g_cod_persona;
            DELETE FROM ge_sol_ver_personas_tmp a
             WHERE a.cod_persona = g_cod_persona;
             --Ejecuto las funciones del paquete
            v_ret_fisicas     := par_per.fu_val_per_fisicas(g_cod_persona,
                                                            g_cod_modulo,
                                                            g_cod_modalidad,
                                                            g_mto_solicitud);
            v_ret_laborales   := par_per.fu_val_per_laborales(g_cod_persona);
            v_ret_financieros := par_per.fu_val_per_financieros(g_cod_persona);
            v_ret_propiedades := par_per.fu_val_per_propiedades(g_cod_persona);
            v_ret_patrimonios := par_per.fu_val_per_patrimonios(g_cod_persona,
                                                                g_mon_local);
            v_ret_personas    := par_per.fu_sol_ver_personas(g_cod_persona,
                                                             g_cod_modulo,
                                                             g_cod_modalidad);
            --Si alguna de las funciones retornó FALSE se devuelve FALSE desde el principal
            IF NOT v_ret_fisicas OR NOT v_ret_laborales OR
               NOT v_ret_financieros OR NOT v_ret_propiedades OR
               NOT v_ret_patrimonios OR NOT v_ret_personas THEN
              v_ret_principal := FALSE;
            END IF;
         END IF;
      END IF;
    END IF;
    RETURN v_ret_principal;
  END;
  -----------------------------------------------------
  FUNCTION fu_val_per_fisicas(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                              p_cod_modulo    IN ba_modulos.cod_modulo%TYPE,
                              p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE,
                              p_mto_solicitud IN pr_solicitudes.monto%TYPE)
    RETURN BOOLEAN IS
    v_ins_registro    VARCHAR2(1) := 'N';
    v_est_civil       ba_per_fisicas.est_civil%TYPE;
    v_conyuge         VARCHAR2(1) := 'N';
    v_mad_hipotecario VARCHAR2(1) := 'N';
    v_mad_construccion VARCHAR2(1) := 'N';
  BEGIN
    --Asigno codigo de persona local a la variable global
    g_cod_persona := p_cod_persona;
    --Busco Estado Civil y Conyuge de la persona
    BEGIN
      SELECT a.est_civil
        INTO v_est_civil
        FROM ba_per_fisicas a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('Persona no definida en (BA_PER_FISICAS).');
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (BA_PER_FISICAS). ' || SQLERRM);
    END;
    --Verifico que se cambie el estado civil cuando sea Otros
    IF v_est_civil = 'O' THEN
      pr_ins_err_tablas('BA_PER_FISICAS',
                        'EST_CIVIL',
                        'Debe cambiar el Estado Civil de la Persona a uno distinto de OTROS.',
                        v_ins_registro);
      RAISE error;
    END IF;
    --Busco si tiene vinculo de conyuge
    BEGIN
      SELECT 'S'
        INTO v_conyuge
        FROM ba_vinculos a
       WHERE a.tipo = 'E'
         AND a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        v_conyuge := 'N';
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (BA_VINCULOS). ' || SQLERRM);
    END;
    --Controlo si la Modalidad es de Tipo Hipotecario
    v_mad_hipotecario := nvl(fug_obt_pardinamico('MAD_HIPOTECARIOS',
                                                  g_cod_modulo,
                                                  g_cod_modalidad),
                             'N');
    v_mad_construccion := nvl(fug_obt_pardinamico('PRE_MAD_CONSTRUCCIONES',
                                                   g_cod_modulo,
                                                   g_cod_modalidad),
                             'N');

    --Si la persona es casada
    IF v_est_civil = 'C' THEN
      --Si no posee Conyuge
      IF v_conyuge = 'N' THEN
        --Si la modalidad es distinta a Hipotecario
        IF v_mad_hipotecario = 'N' AND
           v_mad_construccion = 'N' THEN
          --Si la solicitud corresponde a Consumo
          IF fup_obt_tip_destino(p_cod_persona,
                                 p_cod_modalidad,
                                 g_mon_local,
                                 p_mto_solicitud,
                                 NULL,
                                 p_mto_solicitud,
                                 NULL) = 4 THEN
            --Si el monto de la solicitud es mayor a lo parametrizado en MAX_MTO_SOL_CASADO
            IF p_mto_solicitud > g_mto_max_solicitud THEN
              pr_ins_err_tablas('BA_PER_FISICAS',
                                'COD_PER_CONYUGE',
                                'Para Préstamos de Consumo superiores a ' ||
                                g_mon_local || '.' || g_mto_max_solicitud ||
                                ', será necesario ingresar los datos del cónyuge de esta Persona, que es obligatorio para Personas Casadas sin Separación de Bienes.',
                                v_ins_registro);
            END IF;
          END IF;
          --Si la modalidad corresponde a Hipotecario
        ELSIF v_mad_hipotecario = 'S' OR
              v_mad_construccion = 'S' THEN
          pr_ins_err_tablas('BA_PER_FISICAS',
                            'COD_PER_CONYUGE',
                            'Para Préstamos Hipotecarios, será necesario ingresar los datos del cónyuge de esta Persona, que es obligatorio para Personas Casadas sin Separación de Bienes.',
                            v_ins_registro);
        END IF;
      END IF;
    END IF;
    IF v_ins_registro = 'S' THEN
      RAISE error;
    ELSE
      RAISE salir;
    END IF;
  EXCEPTION
    WHEN salir THEN
      RETURN TRUE;
    WHEN error THEN
      RETURN FALSE;
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.fu_val_per_fisicas). ' || SQLERRM);
  END;
  -----------------------------------------------------
  FUNCTION fu_val_per_laborales(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN IS
    v_ins_registro   VARCHAR2(1) := 'N';
    v_cod_profesion  ba_profesiones.cod_profesion%TYPE;
    v_cod_actividad  ba_personas.cod_actividad%TYPE;
    v_area           ba_telefonos.area%TYPE;
    v_act_interna    ge_actividades.cod_act_interna%TYPE;
    v_can_control    NUMBER := 0;
    v_des_estudiante VARCHAR2(1) := 'N'; --variable desempleado ó estudiante
    --Cursor de Información Laboral de la persona distinta a desempleada o estudiante
    CURSOR c_inf_laboral IS
      SELECT a.*
        FROM cr_inf_laborales a
       WHERE a.cod_persona = p_cod_persona
         AND a.lug_trabajo IS NOT NULL
         AND a.fec_ingreso IS NOT NULL
         AND a.mto_ingreso IS NOT NULL
         AND a.actual = 'S'
         AND a.tip_empleo NOT IN ('S', 'E')
         AND rownum = 1;
  BEGIN
    --Asigno código persona a variable global para cursores globales
    g_cod_persona := p_cod_persona;
    --Busco profesión de la persona
    BEGIN
      SELECT a.cod_profesion
        INTO v_cod_profesion
        FROM ba_per_fisicas a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('Persona no definida en (BA_PER_FISICAS).');
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (BA_PER_FISICAS). ' || SQLERRM);
    END;
    --Controlo de que tenga profesión
    IF v_cod_profesion IS NULL THEN
      pr_ins_err_tablas('BA_PER_FISICAS',
                        'COD_PROFESION',
                        'La persona debe tener configurada una Profesión/Ocupación.',
                        v_ins_registro);
      RAISE error;
    END IF;
    --CROSCOFI-1 - Ajuste SCORING - lcabrera - Julio/2015
    --Si profesion (ba_profesiones) es:
    --Jubilado/Pensionista (código 24)
    ---ó Ama de Casa (código 6)
    ---o Estudiante (código 19)
    ---o Desempleado (código 12) no debe validar el resto
    IF v_cod_profesion IN (6,12,19,24) THEN
      RAISE salir;
    END IF;
    --Busco si la persona tiene informacion laboral
    BEGIN
      SELECT COUNT(1)
        INTO v_can_control
        FROM cr_inf_laborales a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (CR_INF_LABORALES). ' ||
                        SQLERRM);
    END;
    IF v_can_control = 0 THEN
      g_ban_inf_laboral := 'S';
      pr_ins_err_tablas('CR_INF_LABORALES',
                        'COD_PERSONA',
                        'La persona debe tener Información Laboral (Pestaña Laborales).',
                        v_ins_registro);
      RAISE error;
    ELSE
      --CROSCOFI-1 - Ajuste SCORING - lcabrera - Julio/2015
      ----Se comenta por que no existe tipos de empleos S/E (DOMINIO = TIP_EMPLEO)
 /*   --Filtro persona desempleada o estudiante
      BEGIN
        SELECT 'S'
          INTO v_des_estudiante
          FROM cr_inf_laborales a
         WHERE a.cod_persona = p_cod_persona
           AND a.tip_empleo IN ('S', 'E');
      EXCEPTION
        WHEN no_data_found THEN
          v_des_estudiante := 'N';
        WHEN too_many_rows THEN
          RAISE salir;
        WHEN OTHERS THEN
          pr_err_mensajes('Error al consultar (CR_INF_LABORALES). ' ||
                          SQLERRM);
      END;
      IF v_des_estudiante = 'S' THEN
        RAISE salir;
      END IF;*/
      --Busco que tenga al menos un registro bien cargado
      BEGIN
        SELECT COUNT(1)
          INTO v_can_control
          FROM cr_inf_laborales a
         WHERE a.cod_persona = p_cod_persona
           AND a.lug_trabajo IS NOT NULL
           AND a.fec_ingreso IS NOT NULL
           AND a.mto_ingreso IS NOT NULL
           AND a.actual = 'S'
           AND a.tip_empleo NOT IN ('S', 'E');
      EXCEPTION
        WHEN OTHERS THEN
          pr_err_mensajes('Error al consultar (CR_INF_LABORALES). ' ||
                          SQLERRM);
      END;
      IF v_can_control = 0 THEN
        pr_ins_err_tablas('CR_INF_LABORALES',
                          'COD_PERSONA',
                          'La Información Laboral debe estar completa en al menos un registro (Lugar de Trabajo, Fecha de Ingreso, Monto Ingreso, Debe ser Actual).',
                          v_ins_registro);
        RAISE error;
      END IF;
    END IF;
    --Abro cursor de información laboral de la persona
    FOR x IN c_inf_laboral LOOP
      --Si el tipo de ingreso es nulo (ocupacion)
      IF x.tip_ingreso IS NULL THEN
        pr_ins_err_tablas('CR_INF_LABORALES',
                          'TIP_INGRESO',
                          'El valor del Tipo de Ingreso no debe estar nulo.',
                          v_ins_registro);
      END IF;
      --Verifico la direccion laboral de la persona
      IF x.cod_direccion IS NULL THEN
        pr_ins_err_tablas('CR_INF_LABORALES',
                          'COD_DIRECCION',
                          'El valor de la Dirección Laboral no debe estar nulo.',
                          v_ins_registro);
      END IF;
      --Verifico el telefono laboral
      IF x.cod_telefono IS NULL THEN
        pr_ins_err_tablas('CR_INF_LABORALES',
                          'COD_TELEFONO',
                          'El valor del Teléfono Laboral no debe estar nulo.',
                          v_ins_registro);
      ELSE
        --Busco el area definida del telefono laboral
        BEGIN
          SELECT a.area
            INTO v_area
            FROM ba_telefonos a
           WHERE a.cod_persona = g_cod_persona
             AND a.cod_telefono = x.cod_telefono;
        EXCEPTION
          WHEN no_data_found THEN
            pr_err_mensajes('Teléfono no definido en (BA_TELEFONOS). ' ||
                            SQLERRM);
          WHEN OTHERS THEN
            pr_err_mensajes('Error al consultar (BA_TELEFONOS). ' ||
                            SQLERRM);
        END;
        IF v_area IS NULL THEN
          pr_ins_err_tablas('BA_TELEFONOS',
                            'AREA',
                            'El área del Teléfono Laboral debe estar definida.',
                            v_ins_registro);
        END IF;
      END IF;
      --Si profesion es Vicepresidente/Director/Socio
      IF v_cod_profesion = 13 THEN
        --El monto del ingreso de la persona debe ser mayor a lo parametrizado en MAX_MTO_SOL_CASADO
        IF x.mto_ingreso < g_mto_max_solicitud THEN
          pr_ins_err_tablas('PR_SOLICITUDES',
                            'MONTO',
                            'El Monto de Ingreso de la persona debe ser mayor a lo parametrizado en el parámetro dinámico MAX_MTO_SOL_CASADO.',
                            v_ins_registro);
        END IF;
      END IF;
    END LOOP;
    --Busco Actividad de la persona
    BEGIN
      SELECT a.cod_actividad
        INTO v_cod_actividad
        FROM ba_personas a
       WHERE a.cod_persona = g_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('Persona no definida en (BA_PERSONAS).');
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (BA_PERSONAS). ' || SQLERRM);
    END;
    --Verifico la actividad de la persona
    IF v_cod_actividad IS NULL THEN
      pr_ins_err_tablas('BA_PERSONAS',
                        'COD_ACTIVIDAD',
                        'La persona debe tener configurada una Actividad BCP.',
                        v_ins_registro);
    ELSE
      --Verifico que la actividad bcp tenga actividad interna
      BEGIN
        SELECT a.cod_act_interna
          INTO v_act_interna
          FROM ge_actividades a
         WHERE a.cod_actividad = v_cod_actividad;
      EXCEPTION
        WHEN no_data_found THEN
          pr_err_mensajes('Actividad no definida en (GE_ACTIVIDADES). ' ||
                          SQLERRM);
        WHEN OTHERS THEN
          pr_err_mensajes('Error al consultar (GE_ACT_INTERNAS). ' ||
                          SQLERRM);
      END;
      IF v_act_interna IS NULL THEN
        pr_ins_err_tablas('GE_ACTIVIDADES',
                          'COD_ACT_INTERNA',
                          'Actividad Interna (Act. Banco) no definida para la Actividad BCP de la persona.',
                          v_ins_registro);
      END IF;
    END IF;
    IF v_ins_registro = 'S' THEN
      RAISE error;
    ELSE
      RAISE salir;
    END IF;
  EXCEPTION
    WHEN salir THEN
      RETURN TRUE;
    WHEN error THEN
      RETURN FALSE;
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.fu_val_per_laborales). ' ||
                      SQLERRM);
  END;
  -----------------------------------------------------
  FUNCTION fu_val_per_financieros(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN IS
    v_tip_vivienda     ba_tip_viviendas.cod_tip_vivienda%TYPE;
    v_ins_registro     VARCHAR2(1) := 'N';
    v_ctrl_obligatorio VARCHAR2(1);
    v_can_control      NUMBER := 0;
    v_can_ing          NUMBER := 0;
    v_can_egr          NUMBER := 0;
    --Cursor de Información Laboral de la persona
    CURSOR c_inf_laboral IS
      SELECT a.*
        FROM cr_inf_laborales a
       WHERE a.cod_persona = p_cod_persona
         AND a.lug_trabajo IS NOT NULL
         AND a.fec_ingreso IS NOT NULL
         AND a.mto_ingreso IS NOT NULL
         AND a.actual = 'S'
         AND rownum = 1;
    --Cursor de Ingresos y Egresos de la persona
    CURSOR c_per_ing_egresos IS
      SELECT *
        FROM cr_per_ing_egresos a
       WHERE a.cod_persona = p_cod_persona;
    --Cursor de Ingresos y Egresos Obligatorios
    CURSOR c_per_ing_egr_obligatorios IS
      SELECT b.cod_concepto, b.importe, a.tipo
        FROM cr_per_ing_egresos b, cr_con_ing_egr a
       WHERE b.cod_persona = p_cod_persona
         AND b.cod_concepto = a.cod_concepto
         AND nvl(a.obligatorio, 'N') = 'S'
         AND b.importe > 0;
      --CROSCOFI-1 - Ajuste SCORING - lcabrera - Julio/2015 (se cambia condicion a mayor a 0)

    --Cursor de conceptos obligatorios faltantes de la persona
    CURSOR c_con_obl_faltantes (p_tipo cr_con_ing_egr.tipo%type)IS
      SELECT '(' || a.tipo || ')' || a.descripcion dato
        FROM cr_con_ing_egr a
       WHERE nvl(a.obligatorio, 'N') = 'S'
         AND a.tipo = p_tipo
         AND NOT EXISTS (SELECT 1
                FROM cr_per_ing_egresos b
               WHERE b.cod_persona = p_cod_persona
                 AND b.cod_concepto = a.cod_concepto
                 AND b.importe >= 0)
       ORDER BY a.tipo DESC;
    --Cursor de conceptos obligatorios sobrantes de la persona con importe mayor a cero
    CURSOR c_conc_oblig_sobrantes IS
      SELECT '(' || a.tipo || ')' || a.descripcion dato
        FROM cr_con_ing_egr a
       WHERE nvl(a.obligatorio, 'N') = 'S'
         AND EXISTS (SELECT 1
                FROM cr_per_ing_egresos b
               WHERE b.cod_persona = p_cod_persona
                 AND b.cod_concepto = a.cod_concepto
                 AND b.importe > 0)
       ORDER BY a.tipo DESC;
  BEGIN
    --Asigno código persona a variable global para cursores globales
    g_cod_persona := p_cod_persona;
    --Busco tipo de vivienda de la persona
    BEGIN
      SELECT a.cod_tip_vivienda
        INTO v_tip_vivienda
        FROM ba_per_fisicas a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('Persona no definida en (BA_PER_FISICAS).');
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (BA_PER_FISICAS). ' || SQLERRM);
    END;
    --Controlo que la persona tenga vivienda
    IF v_tip_vivienda IS NULL THEN
      g_ban_tip_vivienda := 'S';
      pr_ins_err_tablas('BA_PER_FISICAS',
                        'COD_TIP_VIVIENDA',
                        'La persona debe tener configurada un Tipo de Vivienda.',
                        v_ins_registro);
      RAISE error;
    END IF;
    --Busco si la persona tiene informacion laboral
    BEGIN
      SELECT COUNT(1)
        INTO v_can_control
        FROM cr_inf_laborales a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (CR_INF_LABORALES). ' ||
                        SQLERRM);
    END;
    IF v_can_control = 0 THEN
      IF g_ban_inf_laboral = 'N' THEN
        pr_ins_err_tablas('CR_INF_LABORALES',
                          'COD_PERSONA',
                          'La persona debe tener Información Laboral (Pestaña Laborales).',
                          v_ins_registro);
      END IF;
      RAISE error;
    END IF;
    --Abro cursor de información laboral de la persona
    FOR x IN c_inf_laboral LOOP
      --Si tipo de empleo es Desempleado o Estudiante
      IF x.tip_empleo IN ('S', 'E') THEN
        DECLARE
          v_conceptos VARCHAR2(400) := NULL;
        BEGIN
          --Abro cursor de conceptos de ingresos/egresos obligatorios faltantes
          FOR y IN c_conc_oblig_sobrantes LOOP
            v_conceptos := v_conceptos || y.dato || ',';
          END LOOP;
          IF v_conceptos IS NOT NULL THEN
            v_conceptos := substr(v_conceptos, 1, length(v_conceptos) - 1) || '.';
            --Si el concepto es Obligatorio para tipo de empleo Desempleado o Estudiante
            pr_ins_err_tablas('CR_PER_ING_EGRESOS',
                              'COD_CONCEPTO',
                              'Persona Desempleada/Estudiante no debe poseer: ' ||
                              v_conceptos ||
                              ' En Ingresos/Egresos esto es de carácter obligatorio con monto mayor a cero(0).',
                              v_ins_registro);
          END IF;
        END;
        --Si es otro tipo de empleo
      ELSE
        --Si tipo de vivienda es Propia con Deuda
        IF v_tip_vivienda = 2 THEN
          BEGIN
            SELECT COUNT(1)
              INTO v_can_control
              FROM cr_per_ing_egresos a
             WHERE a.cod_persona = p_cod_persona
               AND a.cod_concepto = 18;
          EXCEPTION
            WHEN OTHERS THEN
              pr_err_mensajes('Error al consultar (CR_PER_ING_EGRESOS). ' ||
                              SQLERRM);
          END;
          IF v_can_control = 0 THEN
            pr_ins_err_tablas('CR_PER_ING_EGRESOS',
                              'COD_CONCEPTO',
                              'Para Tipo de Vivienda 2 (Propia con Deuda), el Tipo de Egreso 18 (Cuota Hipoteca) debe ser obligatorio.',
                              v_ins_registro);
          END IF;
        END IF;
        --Si tipo de vivienda es Alquilada
        IF v_tip_vivienda = 3 THEN
          BEGIN
            SELECT COUNT(1)
              INTO v_can_control
              FROM cr_per_ing_egresos a
             WHERE a.cod_persona = p_cod_persona
               AND a.cod_concepto = 24;
          EXCEPTION
            WHEN OTHERS THEN
              pr_err_mensajes('Error al consultar (CR_PER_ING_EGRESOS). ' ||
                              SQLERRM);
          END;

          IF v_can_control = 0 THEN
            pr_ins_err_tablas('CR_PER_ING_EGRESOS',
                              'COD_CONCEPTO',
                              'Para Tipo de Vivienda 3 (Alquilada), el Tipo de Egreso 24 (Alquileres Pagados) debe ser obligatorio.',
                              v_ins_registro);
          END IF;
        END IF;
        FOR y IN c_per_ing_egresos LOOP
          --Si tipo de vivienda es Propia con Deuda
          IF v_tip_vivienda = 2 THEN
            --Si el concepto es Cuota Hipoteca y el importe 0
            IF y.cod_concepto = 18 AND y.importe = 0 THEN
              pr_ins_err_tablas('CR_PER_ING_EGRESOS',
                                'IMPORTE',
                                'Para Tipo de Vivienda 2 (Propia con Deuda), el importe del Tipo de Egreso 18 (Cuota Hipoteca) debe ser mayor a cero.',
                                v_ins_registro);
            END IF;
          END IF;
          --Si tipo de vivienda es Alquilada
          IF v_tip_vivienda = 3 THEN
            --Si el concepto es Gastos de Alquiler y el importe 0
            IF y.cod_concepto = 24 AND y.importe = 0 THEN
              pr_ins_err_tablas('CR_PER_ING_EGRESOS',
                                'IMPORTE',
                                'Para Tipo de Vivienda 3 (Alquilada), el importe del Tipo de Egreso 24 (Alquileres Pagados) debe ser mayor a cero.',
                                v_ins_registro);
            END IF;
          END IF;
        END LOOP;
        --Busco que la persona tenga todos los conceptos de carácter obligatorio asignados
        BEGIN
          SELECT decode((SELECT COUNT(1)
                          FROM cr_con_ing_egr a
                         WHERE nvl(a.obligatorio, 'N') = 'S'),
                        (SELECT COUNT(1)
                           FROM cr_per_ing_egresos b, cr_con_ing_egr a
                          WHERE b.cod_persona = p_cod_persona
                            AND b.cod_concepto = a.cod_concepto
                            AND nvl(a.obligatorio, 'N') = 'S'
                            AND b.importe >= 0),
                        'S',
                        'N')
            INTO v_ctrl_obligatorio
            FROM dual;
        EXCEPTION
          WHEN OTHERS THEN
            pr_err_mensajes('Error al consultar (COUNT DUAL). ' || SQLERRM);
        END;
      --CROSCOFI-1 - Ajuste SCORING - lcabrera - Julio/2015 (se cambia condicion a mayor a 0)
      --Se pasan los controles mas abajo por que solo se debe exigir cuando no tiene ningun E-ngreso/I-ngreso registrado.
       /* --Si no tiene todos los conceptos obligatorios
        IF v_ctrl_obligatorio = 'N' THEN
          DECLARE
            v_conceptos VARCHAR2(400) := NULL;
          BEGIN
            --Abro cursor de conceptos de ingresos/egresos obligatorios faltantes
            FOR x IN c_con_obl_faltantes LOOP
              v_conceptos := v_conceptos || x.dato || ',';
            END LOOP;

            v_conceptos := substr(v_conceptos, 1, length(v_conceptos) - 1) || '.';

            pr_ins_err_tablas('CR_PER_ING_EGRESOS',
                              'COD_CONCEPTO',
                              'La Persona debe poseer: ' || v_conceptos ||
                              ' En Ingresos/Egresos esto es de carácter obligatorio con monto igual o mayor a cero(0).',
                              v_ins_registro);
          END;
        ELSE*/
          --Si tiene todos los conceptos obligatorios, verifico que el importe no este nulo
          FOR z IN c_per_ing_egr_obligatorios LOOP
            IF z.importe IS NULL THEN
              pr_ins_err_tablas('CR_PER_ING_EGRESOS',
                                'IMPORTE',
                                'El Importe del Concepto de Ingreso/Egreso debe tener un valor.',
                                v_ins_registro);
            ELSE
             IF z.tipo = 'I' then
                v_can_ing := v_can_ing + 1;
             ELSE
                v_can_egr := v_can_egr + 1;
             END IF;
            END IF;
          END LOOP;
          ---Control para exigir registro de Ingresos Obligatorios, solo cuando no tenga uno ya registrado.
          IF v_can_ing = 0 THEN
              DECLARE
                v_conceptos VARCHAR2(400) := NULL;
              BEGIN
                --Abro cursor de conceptos de ingresos/egresos obligatorios faltantes
                FOR x IN c_con_obl_faltantes('I') LOOP
                  v_conceptos := v_conceptos || x.dato || ',';
                END LOOP;

                v_conceptos := substr(v_conceptos, 1, length(v_conceptos) - 1) || '.';

                pr_ins_err_tablas('CR_PER_ING_EGRESOS',
                                  'COD_CONCEPTO',
                                  'La Persona debe poseer al menos uno de los siguientes Ingresos: ' || v_conceptos ||
                                  ' En Ingresos/Egresos esto es de carácter obligatorio con monto mayor a cero(0).',
                                  v_ins_registro);
              END;
          END IF;

          ---Control para exigir registro de Egresos Obligatorios, solo cuando no tenga uno ya registrado.
          IF v_can_egr = 0 then
            DECLARE
              v_conceptos VARCHAR2(400) := NULL;
            BEGIN
              --Abro cursor de conceptos de egresos obligatorios faltantes
              FOR x IN c_con_obl_faltantes('E') LOOP
                v_conceptos := v_conceptos || x.dato || ',';
              END LOOP;

              v_conceptos := substr(v_conceptos, 1, length(v_conceptos) - 1) || '.';

              pr_ins_err_tablas('CR_PER_ING_EGRESOS',
                                'COD_CONCEPTO',
                                'La Persona debe poseer al menos uno de los siguientes Egresos: ' || v_conceptos ||
                                ' En Ingresos/Egresos esto es de carácter obligatorio con monto mayor a cero(0).',
                                v_ins_registro);
            END;
          END IF;
        /*END IF;*/
      END IF;
    END LOOP;
    IF v_ins_registro = 'S' THEN
      RAISE error;
    ELSE
      RAISE salir;
    END IF;
  EXCEPTION
    WHEN salir THEN
      RETURN TRUE;
    WHEN error THEN
      RETURN FALSE;
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.fu_val_per_financieros). ' ||
                      SQLERRM);
  END;
  -----------------------------------------------------
  FUNCTION fu_val_per_propiedades(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN IS
    v_tip_vivienda ba_tip_viviendas.cod_tip_vivienda%TYPE;
    v_ins_registro VARCHAR2(1) := 'N';
    v_can_control  NUMBER := 0;
    v_exi_cuo_alquiler    NUMBER := 0;
    v_exi_cuo_hipoteca    NUMBER := 0;
  BEGIN
    --Asigno código persona a variable global para cursores globales
    g_cod_persona := p_cod_persona;
    --Busco tipo de vivienda de la persona
    BEGIN
      SELECT a.cod_tip_vivienda
        INTO v_tip_vivienda
        FROM ba_per_fisicas a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('Persona no definida en (BA_PER_FISICAS).');
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (BA_PER_FISICAS). ' || SQLERRM);
    END;
    --Controlo que la persona tenga vivienda
    IF v_tip_vivienda IS NULL THEN
      IF g_ban_tip_vivienda = 'N' THEN
        pr_ins_err_tablas('BA_PER_FISICAS',
                          'COD_TIP_VIVIENDA',
                          'La persona debe tener configurada un Tipo de Vivienda.',
                          v_ins_registro);
      END IF;
      RAISE error;
    END IF;
    --Si tipo de vivienda es Propia sin Deuda ó Propia con Deuda
    IF v_tip_vivienda IN (1, 2) THEN
      --Busca cantidad de propiedades de la persona
      BEGIN
        SELECT COUNT(1)
          INTO v_can_control
          FROM cr_per_propiedades a
         WHERE a.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
          pr_err_mensajes('Error al consultar (CR_PER_PROPIEDADES). ' ||
                          SQLERRM);
      END;
      --Si cantidad de propiedades es cero
      IF v_can_control = 0 THEN
        pr_ins_err_tablas('CR_PER_PROPIEDADES',
                          'COD_PERSONA',
                          'La persona debe tener cargada una Propiedad (Pestaña Propiedades).',
                          v_ins_registro);
        --Si la persona posee propiedades
      ELSE
        --Busco que tenga al menos un registro bien cargado
        BEGIN
          SELECT COUNT(1)
            INTO v_can_control
            FROM cr_per_propiedades a
           WHERE a.cod_persona = p_cod_persona
             AND a.nro_finca IS NOT NULL
             AND a.tip_propiedad IS NOT NULL
             AND a.cod_distrito IS NOT NULL
             AND a.cod_moneda IS NOT NULL
             AND a.val_comercial IS NOT NULL
             AND nvl(a.hipotecado, 'N') = 'S'
             AND a.hip_a_quien IS NOT NULL
             AND a.val_hipoteca IS NOT NULL;
        EXCEPTION
          WHEN OTHERS THEN
            pr_err_mensajes('Error al consultar (CR_PER_PROPIEDADES). ' ||
                            SQLERRM);
        END;
      --CROSCOFI-1 - Ajuste SCORING - lcabrera - Julio/2015
      ---Si el tipo de vivienda es Propia con deuda (cód. 2) Obligar la carga del egreso "Cuota Hipoteca" (Cód. 18)
        BEGIN
          SELECT 1
            into v_exi_cuo_hipoteca
            FROM cr_per_ing_egresos b, cr_con_ing_egr a
           WHERE b.cod_persona = p_cod_persona
             AND b.cod_concepto = a.cod_concepto
             AND b.cod_concepto = 18 ---CUOTA HIPOTECA
             AND b.importe > 0;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_exi_cuo_hipoteca := 0;
          WHEN TOO_MANY_ROWS THEN
             v_exi_cuo_hipoteca := 1;
          WHEN OTHERS THEN
            v_exi_cuo_hipoteca := 0;
        END;
        --Si el Tipo de Vivienda es Propia con Deuda controla lo siguiente
        IF v_tip_vivienda = 2 THEN
          IF v_can_control = 0 THEN
            pr_ins_err_tablas('CR_PER_PROPIEDADES',
                              'COD_PERSONA',
                              'La Información de la Propiedad debe estar completa en al menos un registro (Nro. de Finca, Tipo de Propiedad, Distrito, Moneda, Valor Comercial, Debe estar Hipotecado, Valor de a quien esta hipotecado, Valor Hipoteca).',
                              v_ins_registro);
            RAISE error;
          END IF;
       --CROSCOFI-1 - Ajuste SCORING - lcabrera - Julio/2015
          IF nvl(v_exi_cuo_hipoteca,0) = 0 THEN
            pr_ins_err_tablas('CR_PER_INGRESOS',
                              'COD_PERSONA',
                              'El Tipo de Vivienda es Propia con Deuda debe tener registrado egreso Cuota de Hipoteca',
                              v_ins_registro);
            RAISE error;

          END IF;
        END IF;
      END IF;
    ELSIF v_tip_vivienda = 3 THEN
     --CROSCOFI-1 - Ajuste SCORING - lcabrera - Julio/2015
     ---Si el tipo de vivienda Alquilada (cód. 3) Obligar a que este cargado el egreso "Gasto de Alquiler"
        BEGIN
          SELECT 1
            into v_exi_cuo_alquiler
            FROM cr_per_ing_egresos b, cr_con_ing_egr a
           WHERE b.cod_persona = p_cod_persona
             AND b.cod_concepto = a.cod_concepto
             AND b.cod_concepto = 24 ---ALQUILERES PAGADOS
             AND b.importe > 0;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_exi_cuo_alquiler := 0;
          WHEN TOO_MANY_ROWS THEN
            v_exi_cuo_alquiler := 1;
          WHEN OTHERS THEN
            v_exi_cuo_alquiler := 0;
        END;

        IF nvl(v_exi_cuo_alquiler,0) = 0 THEN
          pr_ins_err_tablas('CR_PER_INGRESOS',
                            'COD_PERSONA',
                            'El Tipo de Vivienda es Alquilada debe tener registrado egreso Alquileres Pagados',
                             v_ins_registro);
          RAISE error;

        END IF;

    END IF;
    IF v_ins_registro = 'S' THEN
      RAISE error;
    ELSE
      RAISE salir;
    END IF;
  EXCEPTION
    WHEN salir THEN
      RETURN TRUE;
    WHEN error THEN
      RETURN FALSE;
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.fu_val_per_propiedades). ' ||
                      SQLERRM);
  END;
  -----------------------------------------------------
  FUNCTION fu_val_per_patrimonios(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                  p_mon_local   IN ba_monedas.cod_moneda%TYPE)
    RETURN BOOLEAN IS
    v_ins_registro    VARCHAR2(1) := 'N';
    v_paso            NUMBER;
    v_bie_inmuebles   cr_per_propiedades.val_comercial%TYPE;
    v_val_vehiculos   cr_per_vehiculos.val_comercial%TYPE;
    v_rie_bbva        NUMBER;
    v_tot_deu_sistema ge_clientes.tot_deu_sistema%TYPE;
    v_total           NUMBER;
  BEGIN
    --Asigno codigo de persona local a la variable global
    g_cod_persona := p_cod_persona;
    /*Patrimonio Neto = Suma Activos Fijos - Suma de Deudas.
    Siendo:
    Activos Fijos = Bienes inmuebles + Automóviles.
    Deudas = Riesgo Total BBVA + Riesgo Total en resto Sistema Financiero.*/
    --Busco valor comercial de propiedades
    v_paso := 1;
    SELECT SUM(nvl(a.val_comercial, 0))
      INTO v_bie_inmuebles
      FROM cr_per_propiedades a
     WHERE a.cod_persona = p_cod_persona;
    IF v_bie_inmuebles IS NULL THEN
      v_bie_inmuebles := 0;
    END IF;
    --Busco valor comercial de vehiculos
    v_paso := 2;
    SELECT SUM(nvl(a.val_comercial, 0))
      INTO v_val_vehiculos
      FROM cr_per_vehiculos a
     WHERE a.cod_persona = p_cod_persona;
    IF v_val_vehiculos IS NULL THEN
      v_val_vehiculos := 0;
    END IF;
    --Busco valor de riesgo
    v_paso     := 3;
    v_rie_bbva := nvl(fug_obt_tot_cli_riesgo(p_cod_persona, p_mon_local), 0);
    IF v_rie_bbva IS NULL THEN
      v_rie_bbva := 0;
    END IF;
    --Busco total deuda de la persona
    v_paso := 4;
    SELECT nvl(a.tot_deu_sistema, 0)
      INTO v_tot_deu_sistema
      FROM ge_clientes a
     WHERE a.cod_persona = p_cod_persona;
    IF v_tot_deu_sistema IS NULL THEN
      v_tot_deu_sistema := 0;
    END IF;
    v_paso  := 5;
    v_total := (nvl(v_bie_inmuebles, 0) + nvl(v_val_vehiculos, 0)) -
               (nvl(v_rie_bbva, 0) + nvl(v_tot_deu_sistema, 0));
    --Si el patrimonio resulta negativo actualizamos en cero
    IF nvl(v_total, 0) < 0 THEN
      v_total := 0;
    END IF;
    --Actualizo el Patrimonio Neto de la persona
    BEGIN
      UPDATE ba_per_fisicas a
         SET a.patrimonio = nvl(v_total, 0)
       WHERE a.cod_persona = p_cod_persona;
      IF SQL%NOTFOUND THEN
        pr_ins_err_tablas('BA_PER_FISICAS',
                          'PATRIMONIO',
                          'No se puede actualizar el patrimonio. ' ||
                          SQLERRM,
                          v_ins_registro);
      END IF;
    END;
    IF v_ins_registro = 'S' THEN
      RAISE error;
    ELSE
      RAISE salir;
    END IF;
  EXCEPTION
    WHEN salir THEN
      RETURN TRUE;
    WHEN error THEN
      RETURN FALSE;
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.fu_val_per_patrimonios). Paso ' ||
                      v_paso || ' - ' || SQLERRM);
  END;
  -----------------------------------------------------
  FUNCTION fu_sol_ver_personas(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                               p_cod_modulo    IN ba_modulos.cod_modulo%TYPE,
                               p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE)
    RETURN BOOLEAN IS
    v_ins_registro VARCHAR2(1) := 'N';
    v_plsql        VARCHAR2(4000);
    v_resultado    VARCHAR2(1000);
    v_tablas       ge_par_dinamicos.val_parametro%TYPE;
    CURSOR c_cam_obligatorios IS
      SELECT a.tabla, a.campo, a.msj_error
        FROM ge_cam_obligatorios a
       WHERE a.cod_modulo = p_cod_modulo
         AND a.cod_modalidad = p_cod_modalidad
       ORDER BY a.tabla, a.campo;
  BEGIN
    --Asigno codigo de persona local a la variable global
    g_cod_persona := p_cod_persona;
    FOR x IN c_cam_obligatorios LOOP
      /*Nueva version bancaria, issue NVB-94
      Se parametrizan las tablas que estaran exentas de la funcionalidad de campos obligatorios
      Por mmelgarejo 20/02/2023*/
      IF (INSTR(FUG_OBT_PARDINAMICO('TAB_EXE_CAM_OBLIG'),X.TABLA) = 0) THEN
        v_plsql := 'select ' || to_char(x.campo) || ' from ' || x.tabla ||
                   ' where cod_persona = ' || p_cod_persona;
        IF v_plsql IS NOT NULL THEN
          BEGIN
            EXECUTE IMMEDIATE v_plsql
              INTO v_resultado;
          EXCEPTION
            WHEN no_data_found THEN
              pr_ins_err_tablas(x.tabla,
                                x.campo,
                                'No se ha encontrados datos del cliente ' ||
                                p_cod_persona,
                                v_ins_registro);
              RAISE error;
            WHEN too_many_rows THEN
              NULL;
            WHEN OTHERS THEN
              pr_err_mensajes('Error al ejecutar consulta ' || x.tabla || ' ' ||
                              SQLERRM);
          END;
          IF v_resultado IS NULL /*AND X.TABLA NOT IN (V_TABLAS)*/ THEN
            pr_ins_err_tablas(x.tabla,
                              x.campo,
                              nvl(x.msj_error,
                                  'El valor del campo no debe estar nulo.'),
                              v_ins_registro);
          END IF;
        END IF;
      END IF;
    END LOOP;
    IF v_ins_registro = 'S' THEN
      RAISE error;
    ELSE
      RAISE salir;
    END IF;
  EXCEPTION
    WHEN salir THEN
      RETURN TRUE;
    WHEN error THEN
      RETURN FALSE;
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.fu_sol_ver_personas). ' ||
                      SQLERRM);
  END;
  -----------------------------------------------------
  FUNCTION fu_obt_per_nominas(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2 IS
    v_cuenta ge_cuentas.nro_cuenta%TYPE := NULL;
  BEGIN
    --Asigno codigo de persona local a la variable global
    g_cod_persona := p_cod_persona;
    --Busco la cuenta de pago de salarios de la persona
    SELECT MAX(a.nro_cuenta)
      INTO v_cuenta
      FROM cc_movimientos_his a
     WHERE a.cod_persona = p_cod_persona
       AND a.fecha = (SELECT MAX(b.fecha)
                        FROM cc_movimientos_his b
                       WHERE b.nro_cuenta = a.nro_cuenta
                         AND b.cod_tra_padre = 303)
       AND a.cod_tra_padre = 303
       AND rownum = 1;
    RETURN v_cuenta;
  EXCEPTION
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.fu_obt_per_nominas). ' || SQLERRM);
  END;
  -----------------------------------------------------
  FUNCTION fu_obt_nro_cta_ampliacion(p_nro_solicitud IN ta_sol_lineas.nro_solicitud%TYPE)
    RETURN VARCHAR2 IS
    v_nro_cuenta ta_sol_lineas.nro_cuenta%TYPE;
  BEGIN
    SELECT nro_cuenta
      INTO v_nro_cuenta
      FROM ta_sol_lineas
     WHERE nro_solicitud = p_nro_solicitud
       AND tip_solicitud = 'A';
    RETURN v_nro_cuenta;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.fu_obt_nro_cta_ampliacion). ' || SQLERRM);
  END;
  -----------------------------------------------------
  FUNCTION fu_val_verificaciones(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                                 p_nro_solicitud pr_solicitudes.nro_solicitud%TYPE DEFAULT NULL,
                                 p_cod_modulo    ba_modulos.cod_modulo%TYPE DEFAULT NULL,
                                 p_cod_modalidad ge_modalidades.cod_modalidad%TYPE DEFAULT NULL)
    RETURN VARCHAR2 IS
    v_cod_profesion  ba_profesiones.cod_profesion%TYPE;
    v_tip_vivienda   ba_tip_viviendas.cod_tip_vivienda%TYPE;
    v_tip_persona    ba_personas.tipo%TYPE;
    v_cod_modulo     ba_modulos.cod_modulo%TYPE;
    v_cod_modalidad  ge_modalidades.cod_modalidad%TYPE;
    v_ver_faltantes  VARCHAR2(100) := NULL;
    v_existe         VARCHAR2(1) := 'N';
    v_nec_garantia   VARCHAR2(1) := 'S';
    v_par_dinamico   VARCHAR2(1) := 'N';
    v_mensaje        VARCHAR2(200) := NULL;
    v_dat_modificado VARCHAR2(100) := NULL;
    v_gar            VARCHAR2(50) := NULL; /*20/11/2013 DI PN: Se crea una variable de garantia para la validación
                                                               de garantías de terceros*/
    v_can_gar_terceros    NUMBER;
    v_can_gar_ter_ver   NUMBER;
    v_tie_vigencia   NUMBER := to_number(fug_obt_pardinamico('TIE_VIG_VERIFICACIONES'));
    v_nro_cuenta     ta_cta_tarjetas.nro_cuenta%TYPE;
    v_msj_error      VARCHAR2(200) := NULL;
    CURSOR c_verificaciones IS
      SELECT CASE
               WHEN a.fec_ver_persona IS NULL OR
                    (a.fec_ver_persona IS NOT NULL AND
                    a.fec_ver_persona < SYSDATE - v_tie_vigencia) THEN
                'Personales, '
               ELSE
                NULL
             END per,
             CASE
               WHEN a.fec_ver_laboral IS NULL OR
                    (a.fec_ver_laboral IS NOT NULL AND
                    a.fec_ver_laboral < SYSDATE - v_tie_vigencia) THEN
                'Laborales, '
               ELSE
                NULL
             END lab,
             CASE
               WHEN a.fec_ver_ingreso IS NULL OR
                    (a.fec_ver_ingreso IS NOT NULL AND
                    a.fec_ver_ingreso < SYSDATE - v_tie_vigencia) THEN
                'Ingresos, '
               ELSE
                NULL
             END ing,
             CASE
               WHEN a.fec_ver_egreso IS NULL OR
                    (a.fec_ver_egreso IS NOT NULL AND
                    a.fec_ver_egreso < SYSDATE - v_tie_vigencia) THEN
                'Egresos, '
               ELSE
                NULL
             END egr,
             CASE
               WHEN a.fec_ver_propiedad IS NULL OR
                    (a.fec_ver_propiedad IS NOT NULL AND
                    a.fec_ver_propiedad < SYSDATE - v_tie_vigencia) THEN
                'Propiedades, '
               ELSE
                NULL
             END pro,
             CASE
               WHEN a.fec_ver_garantia IS NULL OR
                    (a.fec_ver_garantia IS NOT NULL AND
                    a.fec_ver_garantia < SYSDATE - v_tie_vigencia) THEN
                'Garantías. '
               ELSE
                NULL
             END gar
        FROM ba_per_validaciones a
       WHERE a.cod_persona = p_cod_persona;
  BEGIN
    --Asigno codigo de persona local a la variable global
    g_cod_persona := p_cod_persona;
    --Busco tipo de persona (Física ó Jurídica)
    BEGIN
      SELECT a.tipo
        INTO v_tip_persona
        FROM ba_personas a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        v_msj_error := 'Persona no definida en (BA_PERSONAS).';
        pr_err_mensajes('Persona no definida en (BA_PERSONAS).');
      WHEN OTHERS THEN
        v_msj_error := 'Error al consultar (BA_PERSONAS). ';
        pr_err_mensajes('Error al consultar (BA_PERSONAS). ' || SQLERRM);
    END;
    --Si es tipo de persona Física
    IF v_tip_persona = 'F' THEN
      --Busco profesión de la persona
      BEGIN
        SELECT nvl(a.cod_profesion, 0), nvl(a.cod_tip_vivienda, 0)
          INTO v_cod_profesion, v_tip_vivienda
          FROM ba_per_fisicas a
         WHERE a.cod_persona = p_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          v_msj_error := 'Persona no definida en (BA_PER_FISICAS).';
          pr_err_mensajes('Persona no definida en (BA_PER_FISICAS).');
        WHEN OTHERS THEN
          v_msj_error := 'Error al consultar (BA_PER_FISICAS). ';
          pr_err_mensajes('Error al consultar (BA_PER_FISICAS). ' ||
                          SQLERRM);
      END;
      IF p_nro_solicitud IS NOT NULL THEN
        IF nvl(p_cod_modulo, 6) = 6 THEN
          BEGIN
            SELECT cod_modulo, cod_modalidad
              INTO v_cod_modulo, v_cod_modalidad
              FROM pr_solicitudes a
             WHERE a.nro_solicitud = p_nro_solicitud;
          EXCEPTION
            WHEN no_data_found THEN
              v_msj_error := 'Solicitud no definida en (PR_SOLICITUDES).';
              pr_err_mensajes('Solicitud no definida en (PR_SOLICITUDES).');
            WHEN OTHERS THEN
              v_msj_error := 'Error al consultar (PR_SOLICITUDES). ';
              pr_err_mensajes('Error al consultar (PR_SOLICITUDES). ' ||
                              SQLERRM);
          END;
          /* 20/11/2013 DI PN: Se agrega para la validación de garantías de terceros */
          BEGIN
            SELECT count(*), sum( CASE WHEN pv.fec_ver_garantia IS NULL OR
                                           (pv.fec_ver_garantia IS NOT NULL AND
                                            pv.fec_ver_garantia < SYSDATE - v_tie_vigencia) THEN
                                            0
                                       ELSE
                                            1
                                    END)
              INTO v_can_gar_terceros, v_can_gar_ter_ver
              FROM pr_sol_garantias sg, pr_garantias g, ba_per_validaciones pv
             WHERE sg.nro_solicitud = p_nro_solicitud
               AND sg.nro_garantia = g.nro_garantia
               AND g.cod_persona = pv.cod_persona
               AND nvl(g.ind_uti_tercero, 'N') = 'S'
               and sg.mto_aplicado <> 0;
          EXCEPTION
            WHEN OTHERS THEN
               v_can_gar_terceros := 0;
               v_can_gar_ter_ver := 0;
          END;

          if nvl(v_can_gar_terceros, 0) <> nvl(v_can_gar_ter_ver, 0) or nvl(v_can_gar_terceros, 0) = 0 then
             v_gar := 'Garantías. ';
          else
             v_gar := null;
          end if;

        ELSE
          v_cod_modulo    := p_cod_modulo;
          v_cod_modalidad := p_cod_modalidad;
        END IF;
        --Verifico Parámetro Dinámico de Modalidades Definidas para el control.
        v_par_dinamico := nvl(fug_obt_pardinamico('SOL_MAD_VERIFICACIONES',
                                                  v_cod_modulo,
                                                  v_cod_modalidad),
                              'N');
      ELSE
        v_par_dinamico := 'S';
      END IF;
      --Realizo la Verifiación sólo para los Módulos y Modalidades definidas.
      IF v_par_dinamico = 'S' THEN
        --Verifico si la solicitud necesita verificación de garantias
        IF p_nro_solicitud IS NOT NULL THEN
          IF nvl(p_cod_modulo, 6) = 6 THEN
            BEGIN
              SELECT 'S'
                INTO v_nec_garantia
                FROM pr_sol_garantias a
               WHERE a.cod_garantia NOT IN (1, 2)
                 AND a.nro_solicitud = p_nro_solicitud;
            EXCEPTION
              WHEN no_data_found THEN
                v_nec_garantia := 'N';
              WHEN too_many_rows THEN
                v_nec_garantia := 'S';
              WHEN OTHERS THEN
                v_msj_error := 'Error al consultar (PR_SOL_GARANTIAS). ';
                pr_err_mensajes('Error al consultar (PR_SOL_GARANTIAS). ' ||
                                SQLERRM);
            END;
          ELSIF p_cod_modulo = 5 THEN
            v_nro_cuenta := fu_obt_nro_cta_ampliacion(p_nro_solicitud);
            IF v_nro_cuenta IS NULL THEN
               BEGIN
                 SELECT 'S'
                   INTO v_nec_garantia
                   FROM ta_sol_garantias a
                  WHERE a.cod_garantia NOT IN (1, 2)
                    AND a.nro_solicitud = p_nro_solicitud;
               EXCEPTION
                 WHEN no_data_found THEN
                   v_nec_garantia := 'N';
                 WHEN too_many_rows THEN
                   v_nec_garantia := 'S';
                 WHEN OTHERS THEN
                   v_msj_error := 'Error al consultar (TA_SOL_GARANTIAS).';
                   pr_err_mensajes('Error al consultar (TA_SOL_GARANTIAS). ' ||
                                  SQLERRM);
               END;
            ELSE
               BEGIN
                 SELECT 'S'
                   INTO v_nec_garantia
                   FROM ta_cta_garantias a
                  WHERE a.cod_garantia NOT IN (1, 2)
                    AND a.nro_cuenta = v_nro_cuenta;
               EXCEPTION
                 WHEN no_data_found THEN
                   v_nec_garantia := 'N';
                 WHEN too_many_rows THEN
                   v_nec_garantia := 'S';
                 WHEN OTHERS THEN
                   v_msj_error := 'Error al consultar (TA_CTA_GARANTIAS). ';
                   pr_err_mensajes('Error al consultar (TA_CTA_GARANTIAS). ' ||
                                  SQLERRM);
               END;
            END IF;
          END IF;
        END IF;
        --Verifico que exista, de no existir toma el exception no_data_found final
        SELECT 'S'
          INTO v_existe
          FROM ba_per_validaciones a
         WHERE a.cod_persona = p_cod_persona;
        IF v_existe = 'S' THEN
          --Control de Modificaciones Realizadas a los Datos tras la Verificación
          SELECT CASE
                   WHEN nvl(a.est_dat_persona, 'M') = 'M' THEN
                    'Personales, '
                   ELSE
                    NULL
                 END || CASE
                   WHEN nvl(a.est_dat_laboral, 'M') = 'M' AND
                        v_cod_profesion NOT IN (78, 120) THEN
                    'Laborales, '
                   ELSE
                    NULL
                 END || CASE
                   WHEN nvl(a.est_dat_ingreso, 'M') = 'M' THEN
                    'Ingresos, '
                   ELSE
                    NULL
                 END || CASE
                   WHEN nvl(a.est_dat_egreso, 'M') = 'M' THEN
                    'Egresos, '
                   ELSE
                    NULL
                 END || CASE
                   WHEN nvl(a.est_dat_propiedad, 'M') = 'M' AND v_tip_vivienda IN (1, 2) THEN
                    'Propiedades. '
                   ELSE
                    NULL
                 END per
            INTO v_dat_modificado
            FROM ba_per_validaciones a
           WHERE a.cod_persona = p_cod_persona;
          IF v_dat_modificado IS NOT NULL THEN
            v_dat_modificado := substr(v_dat_modificado,
                                       1,
                                       length(v_dat_modificado) - 2) || '.';
            v_mensaje        := 'Los Datos fueron modificados y deben ser verificados nuevamente: ';
            v_mensaje        := v_mensaje || v_dat_modificado;
            RETURN v_mensaje;
          END IF;
          --Si profesión es Jubilado/Pensionista ó Ama de Casa se excluye la validación Laboral.
          --Si no requiere garantia (tip.garantia SOLA FIRMA ó CODEUDORIA) se excluye la validación de Garantias.
          --Si no requiere propiedad (tip.vivienda ALQUILADA o COMPARTIDA ALQUILADA) se excluye la validación de Propiedades.
          IF v_cod_profesion NOT IN (78, 120) THEN
            IF v_nec_garantia = 'S' THEN
              IF v_tip_vivienda NOT IN (1, 2) THEN
                FOR a IN c_verificaciones LOOP
                 /* Si la garantía del cliente no esta verificada, busca si tiene asociada la garantia
                    de un tercero*/
                  IF a.gar is not null and v_gar is null then
                     v_gar := null;
                  else
                     v_gar := a.gar;
                  end if;

                  v_ver_faltantes := a.per || a.lab || a.ing || a.egr ||
                                     v_gar;--a.gar;
                END LOOP;
              ELSE
                FOR a IN c_verificaciones LOOP
                 /* Si la garantía del cliente no esta verificada, busca si tiene asociada la garantia
                    de un tercero*/
                  IF a.gar is not null and v_gar is null then
                     v_gar := null;
                  else
                     v_gar := a.gar;
                  end if;

                  v_ver_faltantes := a.per || a.lab || a.ing || a.egr ||
                                     a.pro || v_gar;--a.gar;
                END LOOP;
              END IF;
            ELSE
              IF v_tip_vivienda NOT IN (1, 2) THEN
                FOR a IN c_verificaciones LOOP
                  v_ver_faltantes := a.per || a.lab || a.ing || a.egr;
                END LOOP;
              ELSE
                FOR a IN c_verificaciones LOOP
                  v_ver_faltantes := a.per || a.lab || a.ing || a.egr ||
                                     a.pro;
                END LOOP;
              END IF;
            END IF;
          ELSE
            IF v_nec_garantia = 'S' THEN
              IF v_tip_vivienda NOT IN (1, 2) THEN
                FOR a IN c_verificaciones LOOP
                 /* Si la garantía del cliente no esta verificada, busca si tiene asociada la garantia
                    de un tercero*/
                  IF a.gar is not null and v_gar is null then
                     v_gar := null;
                  else
                     v_gar := a.gar;
                  end if;

                  v_ver_faltantes := a.per || a.ing || a.egr || v_gar;--a.gar;
                END LOOP;
              ELSE
                FOR a IN c_verificaciones LOOP
                 /* Si la garantía del cliente no esta verificada, busca si tiene asociada la garantia
                    de un tercero*/
                  IF a.gar is not null and v_gar is null then
                     v_gar := null;
                  else
                     v_gar := a.gar;
                  end if;

                  v_ver_faltantes := a.per || a.ing || a.egr || a.pro ||
                                     v_gar;--a.gar;
                END LOOP;
              END IF;
            ELSE
              IF v_tip_vivienda NOT IN (1, 2) THEN
                FOR a IN c_verificaciones LOOP
                  v_ver_faltantes := a.per || a.ing || a.egr;
                END LOOP;
              ELSE
                FOR a IN c_verificaciones LOOP
                  v_ver_faltantes := a.per || a.ing || a.egr || a.pro;
                END LOOP;
              END IF;
            END IF;
          END IF;
        END IF;
      END IF;
    END IF;
    IF v_ver_faltantes IS NOT NULL THEN
      v_ver_faltantes := substr(v_ver_faltantes,
                                1,
                                length(v_ver_faltantes) - 2) || '.';
      v_mensaje       := 'Debe realizar las Verificaciones de Datos: ';
      v_mensaje       := v_mensaje || v_ver_faltantes;
      RETURN v_mensaje;
    END IF;
    RETURN v_mensaje;
  EXCEPTION
    WHEN no_data_found THEN
      IF v_nec_garantia = 'S' THEN
        v_ver_faltantes := 'Personales, Laborales, Ingresos, Egresos, Propiedades, Garantías.';
      ELSE
        v_ver_faltantes := 'Personales, Laborales, Ingresos, Egresos, Propiedades.';
      END IF;
      v_mensaje := 'Debe realizar las Verificaciones de Datos: ';
      v_mensaje := v_mensaje || v_ver_faltantes;
      RETURN v_mensaje;
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.fu_val_verificaciones). '||v_msj_error||' ' ||
                      SQLERRM);
  END;
  -----------------------------------------------------
  PROCEDURE pr_ins_err_tablas(p_tabla        IN ge_sol_ver_personas_det_tmp.tabla%TYPE,
                              p_campo        IN ge_sol_ver_personas_det_tmp.campo%TYPE,
                              p_error        IN ge_sol_ver_personas_det_tmp.error%TYPE,
                              p_ins_registro OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;                           
    v_secuencia ge_sol_ver_personas_det_tmp.nro_secuencia%TYPE;
    -- -- -- -- -- -- --
    FUNCTION fu_ver_registro RETURN BOOLEAN IS
      v_existe  VARCHAR2(1);
      v_retorno BOOLEAN := FALSE;
    BEGIN
      BEGIN
        SELECT 'S'
          INTO v_existe
          FROM ge_sol_ver_personas_tmp a
         WHERE a.cod_persona = g_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          v_existe := 'N';
        WHEN too_many_rows THEN
          v_existe := 'S';
        WHEN OTHERS THEN
          v_existe := 'N';
      END;
      IF nvl(v_existe, 'N') = 'S' THEN
        v_retorno := TRUE;
      ELSE
        v_retorno := FALSE;
      END IF;
      RETURN v_retorno;
    END;
    -- -- -- -- -- -- --
    FUNCTION fu_obt_secuencia RETURN NUMBER IS
      v_secuencia ge_sol_ver_personas_det_tmp.nro_secuencia%TYPE;
    BEGIN
      BEGIN
        SELECT nvl(MAX(nro_secuencia), 0) + 1
          INTO v_secuencia
          FROM ge_sol_ver_personas_det_tmp
         WHERE cod_persona = g_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          v_secuencia := 1;
        WHEN OTHERS THEN
          pr_err_mensajes('Error al consultar (GE_SOL_VER_PERSONAS_DET_TMP) (fu_obt_sec). ' ||
                          SQLERRM);
      END;
      RETURN v_secuencia;
    END;
  BEGIN
    v_secuencia := fu_obt_secuencia;
    IF fu_ver_registro THEN
      INSERT INTO ge_sol_ver_personas_det_tmp
        (cod_persona, nro_secuencia, tabla, campo, error)
      VALUES
        (g_cod_persona,
         v_secuencia,
         p_tabla,
         p_campo,
         substr(p_error, 1, 600));
    ELSE
      INSERT INTO ge_sol_ver_personas_tmp
        (cod_persona, cod_modulo, cod_modalidad, monto)
      VALUES
        (g_cod_persona, g_cod_modulo, g_cod_modalidad, g_mto_solicitud);
      INSERT INTO ge_sol_ver_personas_det_tmp
        (cod_persona, nro_secuencia, tabla, campo, error)
      VALUES
        (g_cod_persona,
         v_secuencia,
         p_tabla,
         p_campo,
         substr(p_error, 1, 600));
    END IF;
    commit;
    p_ins_registro := 'S';
  EXCEPTION
    WHEN OTHERS THEN
      pr_err_mensajes('Error en (par_per.pr_inserta_errores). ' || SQLERRM);
  END;
  -----------------------------------------------------
  PROCEDURE pr_err_mensajes(p_mensaje IN VARCHAR2) IS
  BEGIN
    raise_application_error(-20000, p_mensaje);
  END;
  -----------------------------------------------------
  --Fase 2
  FUNCTION fu_ver_reg_antecedentes(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN IS
    v_existe  VARCHAR2(1);
    v_retorno BOOLEAN := FALSE;
  BEGIN
    BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ge_cli_antecedentes a
       WHERE a.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        v_existe := 'N';
      WHEN too_many_rows THEN
        v_existe := 'S';
      WHEN OTHERS THEN
        v_existe := 'N';
    END;
    IF nvl(v_existe, 'N') = 'S' THEN
      v_retorno := TRUE;
    ELSE
      v_retorno := FALSE;
    END IF;
    RETURN v_retorno;
  END;
  -----------------------------------------------------
  FUNCTION fu_obt_dat_infocheck(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2 IS
    v_sit_infochek       ge_cli_antecedentes.sit_infocheck%TYPE;
    v_nro_documento      ba_personas.nro_documento%TYPE;
    v_respuesta          VARCHAR2(4000);
    v_retorno            VARCHAR2(2);
    v_che_rechazados     VARCHAR2(3);
    v_che_rec_historicos VARCHAR2(3);
    v_che_anulados       VARCHAR2(3); --no se tiene en cuenta
    v_inhibiciones       VARCHAR2(3);
    v_inh_historicas     VARCHAR2(3);
    v_con_historicas     VARCHAR2(3); --no se tiene en cuenta
    v_par_ingreso        VARCHAR2(22);
    v_ok                 VARCHAR2(1); -- indica si el socket se corto o no
    v_fec_actual         DATE := pag_cal.fu_obt_fec_actual(1);
    -- -- -- -- -- -- --
    --Obtengo Valor para campo Sit_Infochek
    FUNCTION fl_obt_cod_infocheck RETURN VARCHAR2 IS
    BEGIN
      IF v_che_rechazados = 0 AND v_che_rec_historicos = 0 AND
         v_inhibiciones = 0 AND v_inh_historicas = 0 THEN
        RETURN 1;
      ELSIF v_inhibiciones != 0 THEN
        RETURN 3;
      ELSIF v_inh_historicas != 0 AND v_inhibiciones = 0 THEN
        RETURN 2;
      ELSIF (v_che_rechazados + v_che_rec_historicos) IN (1, 2, 3) THEN
        RETURN 4;
      ELSIF (v_che_rechazados + v_che_rec_historicos) IN (4, 5, 6) THEN
        RETURN 5;
      ELSIF (v_che_rechazados + v_che_rec_historicos) >= 7 THEN
        RETURN 6;
      END IF;
    END;
  BEGIN
    v_nro_documento := fue_obt_nro_doc_persona(p_cod_persona);
    v_par_ingreso   := '01' || lpad(v_nro_documento, 15, ' ');
    --llama a socket
    v_ok := fue_env_tcp_mensajes(g_servidor,
                                 g_puerto,
                                 g_tie_espera,
                                 v_par_ingreso,
                                 v_respuesta);
    IF v_ok != 'S' THEN
      pr_err_mensajes('Error con el Socket Infocheck.');
    ELSE
      v_retorno := substr(v_respuesta, 1, 2);
      IF v_retorno != '00' THEN
        --El codigo 12 es Cliente No Encontrado, igual se actualiza la fecha y asigna 1 por defecto para enviar al motor
        IF v_retorno = '12' THEN
          IF fu_ver_reg_antecedentes(p_cod_persona) THEN
            UPDATE ge_cli_antecedentes a
               SET a.fec_ult_infocheck = v_fec_actual, a.sit_infocheck = 1
             WHERE a.cod_persona = p_cod_persona;
          ELSE
            INSERT INTO ge_cli_antecedentes
              (cod_persona, fec_ult_infocheck, sit_infocheck)
            VALUES
              (p_cod_persona, v_fec_actual, 1);
          END IF;
        END IF;
        --error en la conexion
        RETURN 'Infocheck => ' || substr(v_respuesta, 1, 2) || ' ' || substr(v_respuesta,
                                                                             3,
                                                                             length(v_respuesta));
      ELSE
        v_che_rechazados     := to_number(substr(v_respuesta, 3, 3));
        v_che_rec_historicos := to_number(substr(v_respuesta, 6, 3));
        --v_che_anulados     := to_number(substr(v_respuesta, 9, 3));
        v_inhibiciones   := to_number(substr(v_respuesta, 12, 3));
        v_inh_historicas := to_number(substr(v_respuesta, 15, 3));
        --v_con_historicas     := to_number(substr(v_respuesta, 18, 3));
        v_sit_infochek := fl_obt_cod_infocheck;
        IF fu_ver_reg_antecedentes(p_cod_persona) THEN
          UPDATE ge_cli_antecedentes a
             SET a.sit_infocheck     = v_sit_infochek,
                 a.fec_ult_infocheck = v_fec_actual
           WHERE a.cod_persona = p_cod_persona;
        ELSE
          INSERT INTO ge_cli_antecedentes
            (cod_persona, sit_infocheck, fec_ult_infocheck)
          VALUES
            (p_cod_persona, v_sit_infochek, v_fec_actual);
        END IF;
        RETURN 'Infocheck => OK';
      END IF;
    END IF;
  END;
  -----------------------------------------------------
  FUNCTION fu_obt_dat_informconf(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2 IS
    v_faj_buro      ge_cli_antecedentes.faj_buro%TYPE;
    v_nro_documento ba_personas.nro_documento%TYPE;
    v_par_ingreso   VARCHAR2(22);
    v_retorno       VARCHAR2(2);
    v_respuesta     VARCHAR2(4000);
    v_ok            VARCHAR2(1); -- indica si el socket se corto o no
    v_fec_actual    DATE := pag_cal.fu_obt_fec_actual(1);
  BEGIN
    v_nro_documento := fue_obt_nro_doc_persona(p_cod_persona);
    v_nro_documento := TRIM(REPLACE(to_char(v_nro_documento,
                                            '999G999G999G999'),
                                    ',',
                                    '.'));
    v_par_ingreso   := '02' || lpad(v_nro_documento, 15, ' ');
    --llama a socket
    v_ok := fue_env_tcp_mensajes(g_servidor,
                                 g_puerto,
                                 g_tie_espera,
                                 v_par_ingreso,
                                 v_respuesta);
    IF v_ok != 'S' THEN
      pr_err_mensajes('Error con el Socket Informconf.');
    ELSE
      v_retorno := substr(v_respuesta, 1, 2);
      IF v_retorno != '00' THEN
        --error en la conexion
        RETURN 'Informconf => ' || substr(v_respuesta, 1, 2) || ' ' || substr(v_respuesta,
                                                                              3,
                                                                              length(v_respuesta));
      ELSE
        v_faj_buro := substr(v_respuesta, 4, 1);
        -- Se asigna un valor para clientes con registro no encontrado en Informconf e Informconf bloqueado.
        IF v_faj_buro = '0' THEN
          v_faj_buro := 'P';
        ELSIF v_faj_buro = '1' THEN
          v_faj_buro := 'O';
        END IF;
        IF fu_ver_reg_antecedentes(p_cod_persona) THEN
          UPDATE ge_cli_antecedentes a
             SET a.faj_buro           = v_faj_buro,
                 a.fec_ult_informconf = v_fec_actual
           WHERE a.cod_persona = p_cod_persona;
        ELSE
          INSERT INTO ge_cli_antecedentes
            (cod_persona, faj_buro, fec_ult_informconf)
          VALUES
            (p_cod_persona, v_faj_buro, v_fec_actual);
        END IF;
        RETURN 'Informconf => OK';
      END IF;
    END IF;
  END;
  -----------------------------------------------------
  FUNCTION fu_obt_dat_crc(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN BOOLEAN IS
    rg_cli_antecedentes ge_cli_antecedentes%ROWTYPE;
    v_cat_sis           ge_clientes.cat_sistema%TYPE;
    v_med_dis           ge_cli_antecedentes.med_dispuesto%TYPE;
    v_fecha             DATE;
    v_meses             NUMBER := 6;
    v_ret               VARCHAR2(1) := 'N';
    v_exi_datos         VARCHAR2(1) := 'N';
    v_dat_crc           VARCHAR2(1) := nvl(fug_obt_pardinamico('SCO_DAT_CRC_CLASIFICA'), 'S');

    v_wsi_respuesta     VARCHAR2(2000);
    v_ult_consulta      DATE;
    v_wsi_tot_deu_sis   NUMBER := null;
    v_wsi_contingencia  NUMBER := null;
    v_wsi_cat_sistema   NUMBER := null;
    v_tip_servicio      ge_bcp_dat_personales.tip_servicio%type := paw_bcp.fu_obt_par_bcp_servicios(2, 'N');
  BEGIN
    SELECT add_months(trunc(pag_cal.fu_obt_fec_actual(1)), -v_meses) fecha
      INTO v_fecha
      FROM dual;
    -- Se verifica si existen datos en crc
    BEGIN
      IF v_dat_crc = 'S' THEN
         SELECT tot_dr
           INTO rg_cli_antecedentes.tot_deu_real
           FROM sb_personas_crc_det
          WHERE cod_persona = p_cod_persona
            AND fecha = (SELECT MAX(fecha)
                           FROM sb_personas_crc_det
                          WHERE cod_persona = p_cod_persona);
      ELSE
         SELECT c.tot_dr
           INTO rg_cli_antecedentes.tot_deu_real
           FROM sb_crc_clasificaciones_det c
          WHERE c.cod_persona = p_cod_persona
            AND c.fecha = (SELECT MAX(fecha)
                             FROM sb_crc_clasificaciones_det
                            WHERE cod_persona = p_cod_persona);
      END IF;
      BEGIN
        -- DYDMR-7111 Incidencia SAU - ITGF - Inconvenientes CRC BCP Cliente VIVIANA ALEXANDRA PEREIRA GAONA R:773650
        SELECT nvl(a.tot_deu_real, 0), -- (nvl(a.tot_deu_real, 0) + nvl(a.tot_deu_contingente, 0)),
               nvl(a.tot_deu_sistema, 0),
               nvl(a.tot_deu_con_sistema, 0),
               nvl(a.cat_sistema, 1),
               (nvl(a.tot_deu_real, 0) + nvl(a.tot_deu_sistema, 0))
          INTO rg_cli_antecedentes.tot_deu_real,
               rg_cli_antecedentes.tot_deu_sistema,
               rg_cli_antecedentes.contingencia,
               rg_cli_antecedentes.pro_categoria,
               rg_cli_antecedentes.med_dispuesto
          FROM ge_clientes a
         WHERE a.cod_persona = p_cod_persona;
        rg_cli_antecedentes.dispuesto := nvl(rg_cli_antecedentes.tot_deu_sistema,
                                             0) + nvl(rg_cli_antecedentes.tot_deu_real,
                                                      0);
        v_exi_datos                   := 'S';
      EXCEPTION
        WHEN no_data_found THEN
          rg_cli_antecedentes.tot_deu_sistema := 0;
          rg_cli_antecedentes.dispuesto       := nvl(rg_cli_antecedentes.tot_deu_sistema,
                                                     0) + nvl(rg_cli_antecedentes.tot_deu_real,
                                                              0);
          v_exi_datos                         := 'N';
      END;
    EXCEPTION
      WHEN no_data_found THEN
        --Obtengo los datos
        --Dispuesto,Contingencia,Pro-Categoria,Med-Dispuesto
        BEGIN
          -- DYDMR-7111 Incidencia SAU - ITGF - Inconvenientes CRC BCP Cliente VIVIANA ALEXANDRA PEREIRA GAONA R:773650
          SELECT nvl(a.tot_deu_real, 0) --(nvl(a.tot_deu_real, 0) + nvl(a.tot_deu_sistema, 0))
            INTO rg_cli_antecedentes.tot_deu_real
            FROM ge_clientes a
           WHERE a.cod_persona = p_cod_persona;
          rg_cli_antecedentes.dispuesto := nvl(rg_cli_antecedentes.tot_deu_sistema,
                                               0) + nvl(rg_cli_antecedentes.tot_deu_real,
                                                        0);
          v_exi_datos                   := 'N';
        EXCEPTION
          WHEN no_data_found THEN
            rg_cli_antecedentes.tot_deu_sistema := 0;
            rg_cli_antecedentes.tot_deu_real    := 0;
            rg_cli_antecedentes.dispuesto       := nvl(rg_cli_antecedentes.tot_deu_sistema,
                                                       0) + nvl(rg_cli_antecedentes.tot_deu_real,
                                                                0);
            v_exi_datos                         := 'N';
        END;
    END;
    --Pro-Categoria Historica
    SELECT nvl(MAX(a.cat_sistema), 0)
      INTO v_cat_sis
      FROM ge_clientes_his a
     WHERE a.cod_persona = p_cod_persona
       AND a.fecha >= v_fecha;
    --Pro-Categoria
    IF rg_cli_antecedentes.pro_categoria < v_cat_sis THEN
      rg_cli_antecedentes.pro_categoria := v_cat_sis;
    END IF;
    --Med-Dispuesto Historico
    SELECT nvl(SUM((nvl(a.tot_deu_real, 0) + nvl(a.tot_deu_sistema, 0))), 0)
      INTO v_med_dis
      FROM ge_clientes_his a
     WHERE a.cod_persona = p_cod_persona
       AND a.fecha >= v_fecha;
    --Med-Dispuesto
    rg_cli_antecedentes.med_dispuesto := (rg_cli_antecedentes.med_dispuesto +
                                         v_med_dis) / v_meses;
    --Fec-Ult-Crc
    rg_cli_antecedentes.fec_ult_crc := SYSDATE;
    --Fec-Crc
    SELECT MAX(a.fecha)
      INTO rg_cli_antecedentes.fec_crc
      FROM ge_bcp_clasificacion_cab a;

    ----------SDCBCPSC-1. Consultas a BCP via WS----------
    Begin
        SELECT nvl(max(fec_calendario),(pag_cal.fu_obt_fec_actual(1) -1))
          INTO v_ult_consulta
          FROM ge_bcp_dat_personales
         WHERE cod_persona = p_cod_persona
           AND tip_servicio = v_tip_servicio;
     Exception
       When Others Then
            v_ult_consulta:= (pag_cal.fu_obt_fec_actual(1) -1);
     End;
    IF v_ult_consulta < pag_cal.fu_obt_fec_actual(1) THEN
       v_wsi_respuesta := paw_bcp.fu_pro_bcp_webservice(P_COD_PERSONA, null, 2);
    END IF;

    BEGIN
      SELECT sum(a.mto_deuda), sum(a.mto_contingencia), max(a.cla_sistema)
        INTO v_wsi_tot_deu_sis, v_wsi_contingencia, v_wsi_cat_sistema
        FROM ge_bcp_dat_personales_det a
       WHERE nro_solicitud = (select max(b.nro_solicitud)
                                from ge_bcp_dat_personales b
                               where b.cod_persona = p_cod_persona
                                 and b.tip_servicio = v_tip_servicio)
         AND a.cod_entidad <> '1007';
    EXCEPTION
       WHEN others THEN
          v_wsi_tot_deu_sis := null;
          v_wsi_contingencia:= null;
          v_wsi_cat_sistema := null;
    END;
    rg_cli_antecedentes.dispuesto       := nvl(v_wsi_tot_deu_sis, nvl(rg_cli_antecedentes.tot_deu_sistema, 0)) + nvl(rg_cli_antecedentes.tot_deu_real,0);
    --Pro-Categoria
    IF rg_cli_antecedentes.pro_categoria < nvl(v_wsi_cat_sistema,1) THEN
      rg_cli_antecedentes.pro_categoria := nvl(v_wsi_cat_sistema, 1);
    END IF;
    ------------------------------------------------------

    IF fu_ver_reg_antecedentes(p_cod_persona) THEN
      UPDATE ge_cli_antecedentes a
         SET a.tot_deu_sistema = nvl(v_wsi_tot_deu_sis, nvl(rg_cli_antecedentes.tot_deu_sistema, 0)),
             a.tot_deu_real    = nvl(rg_cli_antecedentes.tot_deu_real, 0),
             a.dispuesto       = nvl(rg_cli_antecedentes.dispuesto, 0),
             a.contingencia    = nvl(v_wsi_contingencia, nvl(rg_cli_antecedentes.contingencia, 0)),
             a.pro_categoria   = rg_cli_antecedentes.pro_categoria,
             a.med_dispuesto   = nvl(rg_cli_antecedentes.med_dispuesto, 0),
             a.fec_ult_crc     = rg_cli_antecedentes.fec_ult_crc,
             a.fec_crc         = rg_cli_antecedentes.fec_crc
       WHERE a.cod_persona = p_cod_persona;
      v_ret := 'S';
    ELSE
      INSERT INTO ge_cli_antecedentes
        (cod_persona,
         tot_deu_sistema,
         tot_deu_real,
         dispuesto,
         contingencia,
         pro_categoria,
         med_dispuesto,
         fec_ult_crc,
         fec_crc)
      VALUES
        (p_cod_persona,
         nvl(v_wsi_tot_deu_sis, nvl(rg_cli_antecedentes.tot_deu_sistema, 0)),
         nvl(rg_cli_antecedentes.tot_deu_real, 0),
         nvl(rg_cli_antecedentes.dispuesto, 0),
         nvl(v_wsi_contingencia, nvl(rg_cli_antecedentes.contingencia, 0)),
         rg_cli_antecedentes.pro_categoria,
         nvl(rg_cli_antecedentes.med_dispuesto, 0),
         rg_cli_antecedentes.fec_ult_crc,
         rg_cli_antecedentes.fec_crc);
      v_ret := 'S';
    END IF;
    IF v_ret = 'S' THEN
      IF v_exi_datos = 'S' THEN
        RAISE salir;
      ELSE
        RAISE error;
      END IF;
    ELSE
      RAISE error;
    END IF;
  EXCEPTION
    WHEN salir THEN
      RETURN TRUE;
    WHEN error THEN
      RETURN FALSE;
    WHEN OTHERS THEN
      RETURN FALSE;
  END;
  -----------------------------------------------------
  FUNCTION fu_obt_des_ale_scoring(p_cod_modulo number,
                                  p_cod_modalidad number,
                                  p_cod_alerta varchar2)
    RETURN VARCHAR2 IS
    v_des_alerta varchar2(200);
    v_cod_alerta varchar2(10);
  BEGIN
    v_cod_alerta := fug_obt_pardinamico('SCO_MAD_GRUPOS',p_cod_modulo, p_cod_modalidad);
    v_cod_alerta := p_cod_alerta||'-'||v_cod_alerta;
    v_des_alerta := fue_obt_des_refcodes('TIP_ALE_SCORING',v_cod_alerta);

    if v_des_alerta like 'No utilizada%'
      or v_des_alerta like 'Referencia  no registrada en el Sistema%' then
      v_des_alerta := null;
    end if;
    RETURN v_des_alerta;
  END;
  -----------------------------------------------------
  FUNCTION fu_obt_dat_inf_economico(p_nro_solicitud number,
                                    p_nro_intento   number,
                                    p_nro_secuencia number,
                                    p_cod_modulo    number,
                                    p_cod_modalidad number)
    RETURN TYP_INFECONOMICOS IS
    v_dat_entrada ge_dat_rie_evaluaciones_det.dat_entrada%type;
    v_retorno     typ_infeconomicos := typ_infeconomicos;
    v_rel_persona varchar2(1);
    v_cod_persona varchar2(10);
  BEGIN
    SELECT dat_entrada, tip_rel_persona, cod_persona
      INTO v_dat_entrada, v_rel_persona, v_cod_persona
      FROM ge_dat_rie_evaluaciones_det a
     WHERE a.nro_solicitud = p_nro_solicitud
       AND a.nro_intento   = p_nro_intento
       AND a.nro_secuencia = p_nro_secuencia
       AND a.cod_modulo    = p_cod_modulo
       AND a.cod_modalidad = p_cod_modalidad;

    pre_cam_for_numerico(',.'); -- prd

    v_retorno.sue_fijo          := nvl(fug_obt_mto_concepto(v_cod_persona,23),0);
    v_retorno.sue_variable      := nvl(fug_obt_mto_concepto(v_cod_persona,9),0);
    v_retorno.ing_independiente := nvl(fug_obt_mto_concepto(v_cod_persona,14),0);
    v_retorno.ing_venta         := nvl(fug_obt_mto_concepto(v_cod_persona,26),0);
    v_retorno.alq_cobrado       := nvl(fug_obt_mto_concepto(v_cod_persona,19),0);
    v_retorno.int_ahorro        := nvl(fug_obt_mto_concepto(v_cod_persona,11),0);
    v_retorno.ren_accion        := nvl(fug_obt_mto_concepto(v_cod_persona,7),0);
    v_retorno.jub_pencion       := nvl(fug_obt_mto_concepto(v_cod_persona,5),0);
    v_retorno.gas_familiar      := nvl(fug_obt_mto_concepto(v_cod_persona,12),0);
    v_retorno.cuo_consumo       := nvl(fug_obt_mto_concepto(v_cod_persona,13),0);
    v_retorno.cuo_tarjeta       := nvl(fug_obt_mto_concepto(v_cod_persona,15),0);
    v_retorno.cuo_hipoteca      := nvl(fug_obt_mto_concepto(v_cod_persona,18),0);
    v_retorno.alq_pagado        := nvl(fug_obt_mto_concepto(v_cod_persona,24),0);
    v_retorno.otr_cuota         := nvl(fug_obt_mto_concepto(v_cod_persona,16),0);
    RETURN v_retorno;
  END;
  -----------------------------------------------------
  --Fase 3
  FUNCTION fu_obt_ult_mto_nomina(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN NUMBER IS
    v_monto         cc_movimientos_his.monto%TYPE := NULL;
    v_fec_proceso   ge_pag_sueldos.fec_proceso%TYPE; --DYDMR-6324
    v_nro_solicitud pr_solicitudes.nro_solicitud%TYPE;
    v_cod_modulo    pr_solicitudes.cod_sub_modalidad%TYPE;
    v_cod_modalidad pr_solicitudes.cod_sub_modalidad%TYPE;
    v_cod_sub_modal pr_solicitudes.cod_sub_modalidad%TYPE;
    v_plazo         NUMBER(3);
    v_parametro     VARCHAR2(400);
    v_fec_actual    ge_calendarios.fec_actual%TYPE := fue_obt_fec_calendar(1);
    v_meses         NUMBER(3);

    CURSOR c_ingresos IS
      SELECT a.cod_persona,a.fec_ingreso,a.mto_ingreso,a.tip_ingreso,b.cod_concepto,b.importe
        FROM cr_inf_laborales a, cr_per_ing_egresos b
       WHERE a.cod_persona(+) = b.cod_persona
         AND b.cod_persona = p_cod_persona
         AND b.cod_concepto IN (23,9)--p_tip_ingreso
         AND b.ing_egreso = 'I'
         AND b.importe > 0
         AND nvl(a.nomina, 'N') = 'S'
         AND a.tip_ingreso(+) = b.cod_concepto;
  BEGIN
    --Asigno codigo de persona local a la variable global
    g_cod_persona := p_cod_persona;

    --DYDMR-6324 verificar si es cliente nomina
    if fug_es_cli_nomina (g_cod_persona) = 'S' then
      --obtener ultimo fecha de proceso de salario
      SELECT MAX(su.fec_proceso)
        INTO v_fec_proceso
        FROM ge_pag_sueldos su, ge_cta_clientes cli
       WHERE su.nro_cuenta = cli.nro_cuenta
         AND cli.relacion = 'P'
         AND cli.cod_persona = g_cod_persona;

      --Verificar sí el ultimo salario acreditado fue dentro de los últimos 60 días
      if v_fec_proceso < trunc(sysdate)-60 then
        v_monto :=0;
      else
         --Sumo los pagos de salarios de la persona correspondiente al último mes de pago.
     select sum(pag_gen.FU_CON_MON_A_MONEDA(s.cod_moneda, 'GS', s.monto))
       into v_monto
       from ge_pag_sue_lotes l, ge_pag_sueldos s, ge_cta_clientes c
      where l.cod_ente(+) = s.cod_ente
        and l.fec_proceso(+) = s.fec_proceso
        and l.nro_secuencia(+) = s.nro_secuencia
        and s.nro_cuenta = c.nro_cuenta
        and c.relacion = 'P'
        and s.procesado = 'S'
        and l.tip_pago(+) = 'S' and s.tipo = 'C' and c.cod_persona = p_cod_persona
        and to_number(to_char(s.fec_proceso,'yyyymm'))= to_number(to_char((v_fec_proceso),'yyyymm'));

      end if;
    end if;
      /**
       * Si es nomina enviamos el monto del ingreso menor al plazo general definido
       */
      IF v_monto > 0 THEN
        -- quitar
        --par_per.g_nro_solicitud := '755422';
        v_nro_solicitud := par_per.g_nro_solicitud;
        -- ceramos monto para informar lo cargado en laborales
        v_monto := 0;
        BEGIN
          SELECT a.cod_modulo,a.cod_modalidad,a.cod_sub_modalidad
            INTO v_cod_modulo,v_cod_modalidad,v_cod_sub_modal
            FROM pr_solicitudes a
           WHERE a.nro_solicitud = v_nro_solicitud;
        EXCEPTION
        WHEN no_data_found THEN
          BEGIN
            SELECT a.cod_modulo,a.cod_modalidad,a.cod_sub_modalidad
              INTO v_cod_modulo,v_cod_modalidad,v_cod_sub_modal
              FROM ta_solicitudes a
             WHERE a.nro_solicitud = v_nro_solicitud;
          EXCEPTION
            WHEN no_data_found THEN
              v_cod_modulo    := 0;
              v_cod_modalidad := 0;
              v_cod_sub_modal := 0;
          END;
        END;
        v_parametro := NVL(fug_obt_pardinamico('SCO_SUB_MOD_EXCEPCIONES',v_cod_modulo,v_cod_modalidad,NULL,NULL,v_cod_sub_modal),'PLA_GENERAL');
        FOR i IN c_ingresos LOOP
          v_plazo := NVL(fue_tab_dat_adicional('CR_CON_ING_EGR',v_parametro,i.cod_concepto),
                         fue_tab_dat_adicional('CR_CON_ING_EGR',v_parametro,i.cod_concepto));
          v_meses := round((v_fec_actual-NVL(i.fec_ingreso,v_fec_actual))/30);
          IF v_meses < v_plazo THEN
            -- mayor al plazo se toma todo los ingresos
            v_monto := v_monto + i.mto_ingreso;
          /*ELSE
            v_monto := 0;*/
          END IF;
        END LOOP;
      END IF;
      return nvl(v_monto,0);

  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        return nvl(v_monto,0);
     WHEN OTHERS THEN
        pr_err_mensajes('Error en (par_per.fu_obt_ult_mto_nomina). ' ||
                      SQLERRM);
  END;
  PROCEDURE pr_gen_rie_evaluaciones(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                                    p_nro_intento   OUT NUMBER,
                                    p_mensaje       OUT VARCHAR2,
                                    p_cod_modulo    IN ba_modulos.cod_modulo%TYPE,
                                    p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE) IS
    v_cod_modulo           ba_modulos.cod_modulo%TYPE;
    v_cod_modalidad        ge_modalidades.cod_modalidad%TYPE;
    v_cod_persona          ba_personas.cod_persona%TYPE;
    v_intento              ge_dat_rie_evaluaciones.nro_intento%TYPE;
    v_version              ge_dat_rie_evaluaciones.ver_flujo%TYPE;
    v_reservado            ge_dat_rie_evaluaciones.reservado%TYPE;
    v_nivel                ge_dat_rie_evaluaciones.nivel%TYPE;
    v_flujo                ge_dat_rie_evaluaciones.cod_flujo%TYPE;
    v_nro_secuencia        ge_dat_rie_evaluaciones_det.nro_secuencia%TYPE := 1;
    rg_evaluaciones_det    ge_dat_rie_evaluaciones_det%ROWTYPE;
    v_estado               pr_solicitudes.estado%TYPE;
    v_est_verificacion     pr_solicitudes.est_verificacion%TYPE;
    v_cod_moneda           pr_solicitudes.cod_moneda%TYPE;
    v_mto_interes          pr_solicitudes.mto_interes%TYPE;
    v_monto                pr_solicitudes.monto%TYPE;
    v_dia_plazo            pr_solicitudes.dia_plazo%TYPE;
    v_tip_prestamo         pr_solicitudes.tipo%TYPE;
    v_tip_destino          pr_solicitudes.tip_destino%TYPE;
    v_lin_credito          pr_solicitudes.nro_linea%TYPE := NULL;
    v_cod_campana          pr_solicitudes.cod_campana%TYPE := NULL;
    v_est_linea            pr_lineas.estado%TYPE := NULL;
    v_cod_per_vinculo      ba_vinculos.cod_per_vinculo%TYPE;
    v_fec_informconf       ge_cli_antecedentes.fec_ult_informconf%TYPE;
    v_fec_infocheck        ge_cli_antecedentes.fec_ult_infocheck%TYPE;
    v_dat_entrada          LONG;
    v_cad_principal        VARCHAR2(4000);--CROBPEFX-1: Se aumenta el tamaño en el Proyecto de Equifax.-
    v_cad_operacion        VARCHAR2(1000);
    v_cad_conyuge          VARCHAR2(4000);
    v_cad_codeudor         VARCHAR2(4000);
    v_cad_codeudores       LONG;
    v_cadena               VARCHAR2(1300);
    v_intervinientes       VARCHAR2(100);
    v_can_personas         NUMBER := 0; --cantidad personas vinculadas
    v_posicion             NUMBER; --posición final del detalle del principal
    v_pre_aprobado         VARCHAR2(1) := 'N';
    v_respuesta            VARCHAR2(4000);
    v_ok                   VARCHAR2(1); -- indica si el socket se corto o no
    v_servidor             VARCHAR2(20) := fug_obt_pardinamico('DIP_SCK_EVA_SCORING'); --'62.0.127.90';
    v_puerto               NUMBER(4) := to_number(fug_obt_pardinamico('PTO_SCK_EVA_SCORING')); --4467;
    v_tie_espera           NUMBER(4) := NULL;
    v_par_dinamico         VARCHAR2(1) := 'N';
    v_act_est_verificacion VARCHAR2(1) := 'N'; --Indicador de actualización de est_verificacion
    v_mad_hipotecario      VARCHAR2(1) := 'N';
    v_dat_obligatorios     BOOLEAN;
    v_codeudor             Varchar2(1);
    v_cuota                varchar2(20);
    v_importe              number;
    -- DYDMR-5927 Ene/2017 NAF
    v_pun_scoring number(17,9);
    v_can_alertas number default fug_obt_pardinamico('SCO_CAN_ALERTAS');

    CURSOR codeudores IS --Cursor que contiene los datos de personas vinculadas a solicitudes de prestamos modulo 6
      SELECT g.nro_garantia, g.nro_solicitud
        FROM pr_sol_garantias g, ba_per_fisicas f
       WHERE nro_solicitud = p_nro_solicitud
         AND f.cod_persona = g.nro_garantia
         AND cod_garantia = 2;
    CURSOR tar_codeudores IS  --Cursor que contiene los datos de personas vinculadas a solicitudes de tarjetas modulo 5
      SELECT t.nro_garantia, t.nro_solicitud
        FROM ta_sol_garantias t, ba_per_fisicas f
       WHERE t.nro_solicitud = p_nro_solicitud
         AND f.cod_persona = t.nro_garantia
         AND t.cod_garantia = 2
      UNION ALL
      SELECT g.nro_garantia, t.nro_solicitud
        FROM ta_sol_lineas t, ta_cta_garantias g, ba_per_fisicas f
       WHERE t.nro_solicitud = p_nro_solicitud
         AND t.tip_solicitud = 'A'
         AND t.nro_cuenta = g.nro_cuenta
         AND f.cod_persona = g.nro_garantia
         AND g.cod_garantia = 2 ;

    FUNCTION fl_obt_des_especifico(p_nro_solicitud in ge_dat_rie_evaluaciones.nro_solicitud%TYPE)
      RETURN VARCHAR2 IS

   --CROSCOFI-1 - Ajuste SCORING - lcabrera - Julio/2015
    v_cod_des_especifico  varchar2(3);

    BEGIN
      SELECT lpad(ltrim(nvl(e.tip_des_especifico, 0)), 3, '0')
        INTO v_cod_des_especifico
        FROM pr_sol_destinos e
       WHERE e.nro_solicitud = p_nro_solicitud
         AND rownum = 1;

      RETURN v_cod_des_especifico;

    EXCEPTION
      WHEN no_data_found THEN
        v_cod_des_especifico := '000';
        RETURN v_cod_des_especifico;
      WHEN OTHERS THEN
        v_cod_des_especifico := '000';
        RETURN v_cod_des_especifico;
    END;
    FUNCTION fl_obt_cad_operacion(p_nro_solicitud IN ge_dat_rie_evaluaciones.nro_solicitud%TYPE,
                                  p_cod_modulo    IN ba_modulos.cod_modulo%TYPE,
                                  p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE,
                                  p_codeudor      In Varchar2 Default 'N')
      RETURN VARCHAR2 IS
    BEGIN
      SELECT p.afinidad || p.canal || p.codcamapro || p.destino ||
             p.esdebitoautom || p.fechasolicitud || p.modalidad ||
             p.monedamonto || p.monedamontolin || p.monedavalgar ||
             p.montoaplicado || p.montolinea || p.montosolicitado ||
             p.numcuotas || p.numpropuesta || p.oficina || p.plazo ||
             p.tasacion || p.tasainteres || p.tipobien || DECODE(P_CODEUDOR, 'N', P.TIPOGARANTIA, '001') ||
             p.valorgarantia || p.valorpresupuesto||p.sub_modalidad ||p.cod_ent_concesionaria||
             p.cod_marca || p.cod_origen || p.cotizacion || p.totprestamos || p.cuotapr
        INTO v_cadena
        FROM gv_rie_eva_operaciones p
       WHERE p.nro_solicitud = p_nro_solicitud
         AND p.modalidad = p_cod_modalidad
         AND p.modulo = p_cod_modulo
         AND rownum = 1;
      --CROSCOFI-1 - Ajuste SCORING - lcabrera - Julio/2015
      v_cadena := v_cadena || fl_obt_des_especifico(p_nro_solicitud) ;

      RETURN v_cadena;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('No se han encontrado datos de la Operación. ' ||
                        p_nro_solicitud);
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (GV_RIE_EVA_OPERACION). ' ||
                        SQLERRM);
    END;
    FUNCTION fl_obt_cad_personas(p_cod_persona     ge_dat_rie_evaluaciones_det.cod_persona%TYPE,
                                 p_tip_rel_persona ge_dat_rie_evaluaciones_det.tip_rel_persona%TYPE)
      RETURN VARCHAR2 IS
      v_nro_sol_origen pr_solicitudes.nro_solicitud%TYPE;
      v_tip_producto   varchar2(2);
      --CROBPEFX-1: Proyecto de Equifax.-
      v_dat_equifax          varchar2(4000);
      FUNCTION FL_OBT_DAT_EQUIFAX(P_COD_PERSONA  BA_PERSONAS.COD_PERSONA%TYPE) RETURN VARCHAR2 IS
       V_RETORNO VARCHAR2(4000);
       CURSOR DATOS IS
             select substr(abreviatura,instr(abreviatura,':')+2)   var_socket,
                    b.res_consulta                                 dato,
                    substr(abreviatura,1,instr(abreviatura,':')-2) longitud
              From ba_cod_referencias a, ge_equ_consultas_det b
              where a.dominio     = 'CAM_RES_EQUIFAX'
                and a.abreviatura is not null
                and a.val_minimo  = b.nom_campo
                and b.cod_persona = P_COD_PERSONA
              order by to_number(val_maximo);
      BEGIN
            V_RETORNO := NULL;
            FOR I IN DATOS LOOP
                  V_RETORNO := V_RETORNO||lpad(nvl(i.dato,0),i.longitud,' ');
            END LOOP;
            RETURN V_RETORNO;
      EXCEPTION
          WHEN OTHERS THEN
               pr_err_mensajes('Error en FL_OBT_DAT_EQUIFAX. '||SQLERRM);
      END;
      --
       function fl_obt_dat_personas
         return varchar2 is
         v_cod_tip_doc ba_personas.cod_tip_documento%type;
         v_retorno varchar2(4000);
         v_sit_lab varchar2(3);
         v_des_jub varchar2(24);
         v_indice  number;
         cursor c_dat is
           select *
             from cr_inf_laborales a
            where a.cod_persona = p_cod_persona
              and a.actual = 'S'
            order by a.mto_ingreso desc, a.fec_ingreso desc;

       BEGIN
         v_retorno := null;
         -- Tipo de Documento (2 x 1)
         begin
           select a.cod_tip_documento
             into v_cod_tip_doc
             from ba_personas a
            where a.cod_persona = p_cod_persona;
         end;
         v_retorno := rpad(v_cod_tip_doc,2,' ');
         v_indice := 0;
         -- Situación Laboral (1 x 3)
         for i in c_dat loop
           v_indice := v_indice + 1;
           if v_indice > 1 and v_indice <= 4 then
             v_sit_lab := v_sit_lab || nvl(i.tip_empleo,' ');
           end if;
         end loop;
         if v_sit_lab is not null then
           v_sit_lab := rpad(v_sit_lab,3,' ');
         else
           v_sit_lab := '   ';
         end if;
         v_retorno := v_retorno||v_sit_lab;
         v_indice := 0;
         -- Porcentaje Descuento Jubilatorio (6x4)
         for i in c_dat loop
           v_indice := v_indice + 1;
           if v_indice <= 4 then
             v_des_jub := v_des_jub || rpad(i.por_des_jubilatorio,6,' ');
             if i.por_des_jubilatorio is null then
               v_des_jub := v_des_jub||'      ';
             end if;
           end if;
         end loop;
         v_retorno := v_retorno||v_des_jub;
         return rpad(v_retorno,29,' ');
       exception
         when others then
           pr_err_mensajes('Error en fl_obt_dat_personas. ' || SQLERRM);
       END;
    BEGIN
      --SDHSCORM-1
      v_importe := 0;
      par_per.g_nro_solicitud := p_nro_solicitud;
      IF p_tip_rel_persona = 'P' AND
         v_cod_campana = fug_obt_pardinamico('SCO_MUL_CAMPANA', v_cod_modulo) THEN
         BEGIN
            IF p_cod_modulo = 6 THEN
              SELECT max(to_number(a.val_parametro))
                INTO v_nro_sol_origen
                FROM ba_tab_dat_adicionales a
               WHERE a.parametro='SCO_MUL_NRO_SOL_ORI'
                 AND a.tab_relacion = 'PR_SOLICITUDES' -- Si la solicitud padre es TDC, buscar en PR_SOLICITUDES.
                 AND a.referencia = p_nro_solicitud;
            ELSIF p_cod_modulo = 5 THEN
              SELECT max(to_number(a.val_parametro)), 'TA'
                INTO v_nro_sol_origen, v_tip_producto
                FROM ba_tab_dat_adicionales a
               WHERE a.parametro='SCO_MUL_NRO_SOL_ORI'
                 AND a.tab_relacion = 'TA_SOLICITUDES' -- Si la solicitud padre es Prest., buscar en TA_SOLICITUDES o TA_SOL_LINEAS.
                 AND a.referencia = p_nro_solicitud;
               IF v_nro_sol_origen is null THEN
                  SELECT max(to_number(a.val_parametro)), 'AL'
                    INTO v_nro_sol_origen, v_tip_producto
                    FROM ba_tab_dat_adicionales a
                   WHERE a.parametro='SCO_MUL_NRO_SOL_ORI'
                     AND a.tab_relacion = 'TA_SOL_LINEAS' -- Si la solicitud padre es Prest., buscar en TA_SOLICITUDES o TA_SOL_LINEAS.
                     AND a.referencia = p_nro_solicitud;
               END IF;
            END IF;
         EXCEPTION
            WHEN others THEN
               v_nro_sol_origen := null;
         END;
         IF v_nro_sol_origen IS NOT NULL THEN
            IF v_cod_modulo = 5 THEN
               BEGIN
                  SELECT NVL(max(a.mto_capital + a.val_interes), 0) -- La cuota más alta
                    INTO v_importe
                    FROM pr_sol_cuotas a, pr_solicitudes b
                   WHERE b.nro_solicitud = a.nro_solicitud
                     AND b.estado IN ('S','L','E','C')
                     AND b.nro_solicitud = v_nro_sol_origen
                     -- Para que tome solo si el dictamen de la última evaluación fue: 1=Conceder o 3=Duda
                     AND exists (SELECT 1 FROM ge_dat_rie_evaluaciones c
                                  WHERE c.nro_solicitud=b.nro_solicitud and c.cod_modulo=b.cod_modulo
                                    AND c.cod_modalidad=b.cod_modalidad and c.dic_final in (1,3)
                                    AND c.nro_intento = (SELECT max(d.nro_intento)
                                                           FROM ge_dat_rie_evaluaciones d
                                                          WHERE c.nro_solicitud=d.nro_solicitud
                                                            AND c.cod_modulo=d.cod_modulo
                                                            AND c.cod_modalidad=d.cod_modalidad));
               EXCEPTION
                   WHEN others THEN
                      v_importe := 0;
               END;
            ELSIF v_cod_modulo = 6 THEN
               IF v_tip_producto = 'TA' THEN
                  BEGIN
                     SELECT nvl(monto/10, 0) -- Obtener el 10% del monto de la línea
                       INTO v_importe
                       FROM ta_solicitudes b
                      WHERE nro_solicitud = v_nro_sol_origen
                        AND cod_estado IN ('PAN','PVC','APR')
                        -- Para que tome solo si el dictamen de la última evaluación fue: 1=Conceder o 3=Duda
                        AND exists (SELECT 1 FROM ge_dat_rie_evaluaciones c
                                     WHERE c.nro_solicitud=b.nro_solicitud and c.cod_modulo=b.cod_modulo
                                       AND c.cod_modalidad=b.cod_modalidad and c.dic_final in (1,3)
                                       AND c.nro_intento = (SELECT max(d.nro_intento)
                                                              FROM ge_dat_rie_evaluaciones d
                                                             WHERE c.nro_solicitud=d.nro_solicitud
                                                               AND c.cod_modulo=d.cod_modulo
                                                               AND c.cod_modalidad=d.cod_modalidad));
                  EXCEPTION
                     WHEN others THEN
                        v_importe := 0;
                  END;
               ELSIF v_tip_producto = 'AL' THEN
                  BEGIN
                     SELECT nvl((b.lin_credito - nvl(b.mto_lin_anterior, 0))/10, 0) -- Obtener el 10% del monto del Aumento
                       INTO v_importe
                       FROM ta_sol_lineas b, ta_cta_tarjetas e
                      WHERE b.nro_cuenta = e.nro_cuenta
                        AND b.nro_solicitud = v_nro_sol_origen
                        AND b.cod_estado IN ('PAN','PVC','APR')
                        -- Para que tome solo si el dictamen de la última evaluación fue: 1=Conceder o 3=Duda
                        AND exists (SELECT 1 FROM ge_dat_rie_evaluaciones c
                                     WHERE c.nro_solicitud=b.nro_solicitud and c.cod_modulo=e.cod_modulo
                                       AND c.cod_modalidad=e.cod_modalidad and c.dic_final in (1,3)
                                       AND c.nro_intento = (SELECT max(d.nro_intento)
                                                              FROM ge_dat_rie_evaluaciones d
                                                             WHERE c.nro_solicitud=d.nro_solicitud
                                                               AND c.cod_modulo=d.cod_modulo
                                                               AND c.cod_modalidad=d.cod_modalidad));
                  EXCEPTION
                     WHEN others THEN
                        v_importe := 0;
                  END;
               END IF;
            END IF;
         END IF;
      END IF;
      ----------------------------------------------------------------------
      SELECT g.actividadcli || g.actual || g.alquilercob ||
             g.alquilercobcon || g.carrerauniver || g.categoriaclibcp ||
             g.codcliente ||
             lpad(ltrim(to_char(nvl(g.cuotaconsumo+v_importe, 0), '999999999999990D99')), 20, ' ') ||
             g.cuotaconsumocon ||
             g.cuotahip || g.cuotahipcon || g.cuotaotras || g.cuotaotrascon ||
             g.cuotatarj || g.cuotatarjcon || g.diasatro ||
             g.dispuestoclisf || g.esclipreferente || g.esfijo ||
             g.estadocivil || g.fajaburo || g.fecaltacliente ||
             g.fechaingresoemp || g.fecnacimiento || g.gastoalquiler ||
             g.gastofamiliar || g.gestor || g.mtonomina || g.infocheck ||
             g.ingesosventacon || g.ingesosventas || g.ingresosind ||
             g.ingresosindcon || g.interesesaho || g.interesesahocon ||
             g.jubypension || g.jubypensioncon || g.limcontingente ||
             g.marcaclicastigo || g.maxdiasincum12 || g.maxdiasincum6 ||
             g.mddispclibcp6 || g.montoatrfecsol || g.montomaxincum12 ||
             g.montomaxincum6 ||
             lpad(ltrim(to_char(TRIM(g.ingresosind) + TRIM(g.sueldofijo) +
                                TRIM(g.sueldovar) + TRIM(g.alquilercob) +
                                TRIM(g.interesesaho) + TRIM(g.rentasaccion) +
                                TRIM(g.jubypension),
                                '999999999999990D99')),
                  20,
                  ' ') || g.nivelestudios || g.numconyuge ||
             g.numpersonacargo || g.pagominimo || g.paisorigen ||
             g.patrimonio || g.peorcatclibcp6 || g.profesion ||
             g.rentasaccion || g.rentasaccioncon || g.saldomediopv ||
             g.sexo || g.situacionlab || g.sueldofijo || g.sueldofijocon ||
             g.sueldovar || g.sueldovarcon || g.tarjetabloq ||
             p_tip_rel_persona || g.tipopropiedad || g.tipovivienda ||
             g.valcompropiedad || g.cre_pro_nomina ||
             g.fechaingresoemp1 || g.fechaingresoemp2 || g.fechaingresoemp3
        INTO v_cadena
        FROM gv_rie_eva_personas g
       WHERE g.cod_persona = p_cod_persona
         AND rownum = 1;
      v_cadena := v_cadena||fl_obt_dat_personas;
      IF nvl(fug_obt_pardinamico('SCO_SCK_DAT_EQUIFAX'), 'N') = 'S' THEN
         V_DAT_EQUIFAX   := FL_OBT_DAT_EQUIFAX(V_COD_PERSONA);--CROBPEFX-1: Proyecto de Equifax.-
      END IF;
      RETURN v_cadena || v_dat_equifax;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('No se han encontrado datos de la Persona. ' ||
                        p_cod_persona);
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (GV_RIE_EVA_PERSONAS). ' ||
                        SQLERRM);
    END;
    --Validación de cantidad de intentos de acuerdo al Rol del usuario
    procedure pl_ver_rol_can_intentos(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
                                      p_cod_modulo    IN ge_dat_rie_eva_intentos.cod_modulo%TYPE,
                                      p_cod_modalidad IN ge_dat_rie_eva_intentos.cod_modalidad%TYPE) IS
       v_cod_rol      ba_roles.cod_rol%TYPE;
       v_can_intentos ge_dat_rie_eva_intentos.can_intentos%type;
    begin
       if not fug_val_usu_rol('ROL_DPTO_COM_EVALUACION', USER) and not fug_val_usu_rol('ROL_DPTO_RIE_EVALUACION', USER) then
          pr_err_mensajes('Usuario no posee habilitado el Rol para el Dpto. de Riesgo o Dpto. Comercial para realizar la Evaluación.');
       end if;
       if fug_val_usu_rol('ROL_DPTO_COM_EVALUACION', USER) then
          v_cod_rol := fug_obt_pardinamico('ROL_DPTO_COM_EVALUACION'); -- DPTO_COM_EVALUACION
          --**obtener la cantidad de intentos
          begin
             select can_intentos
               into v_can_intentos
               from ge_dat_rie_eva_intentos
              where nro_solicitud = p_nro_solicitud
                and cod_modulo = p_cod_modulo
                and cod_modalidad = p_cod_modalidad
                and cod_rol = v_cod_rol;
          exception
             when no_data_found then
               v_can_intentos := 0;
          end;

          begin
            if v_can_intentos >= to_number(fug_obt_pardinamico('CAN_DPTO_COM_EVALUACION', p_cod_modulo, p_cod_modalidad)) THEN

                pr_err_mensajes('Cantidad de Intentos de Simulación para Dpto. Comercial superada.');
            end if;
          end;
       end if;

       if fug_val_usu_rol('ROL_DPTO_RIE_EVALUACION', USER) then
          v_cod_rol := fug_obt_pardinamico('ROL_DPTO_RIE_EVALUACION'); -- DPTO_RIE_EVALUACION
          --**obtener la cantidad de intentos
          begin
             select can_intentos
               into v_can_intentos
               from ge_dat_rie_eva_intentos
              where nro_solicitud = p_nro_solicitud
                and cod_modulo = p_cod_modulo
                and cod_modalidad = p_cod_modalidad
                and cod_rol = v_cod_rol;
          exception
             when no_data_found then
                v_can_intentos := 0;
          end;

          IF v_can_intentos >= to_number(fug_obt_pardinamico('CAN_DPTO_RIE_EVALUACION', p_cod_modulo, p_cod_modalidad)) THEN
             pr_err_mensajes('Cantidad de Intentos de Simulación para Dpto. de Riesgos superada.');
          end if;
       end if;
    exception
       when others then
          If sqlcode <= -20000 then
             raise;
          else
             raise_application_error(-20000, 'Error en (PL_VER_ROL_CAN_INTENTOS). ' || SQLERRM);
          end if;
    end;
    -- Realiza la inserción y actualización de la nueva tabla GE_DAT_RIE_EVA_INTENTOS.
    procedure pl_act_can_intentos(p_nro_solicitud IN ge_dat_rie_evaluaciones.nro_solicitud%TYPE,
                                  p_cod_modulo    IN ge_dat_rie_eva_intentos.cod_modulo%TYPE,
                                  p_cod_modalidad IN ge_dat_rie_eva_intentos.cod_modalidad%TYPE) IS
       v_cod_rol  ba_roles.cod_rol%TYPE;
       v_cantidad number;
    begin
       if fug_val_usu_rol('ROL_DPTO_COM_EVALUACION', USER) then
          v_cod_rol := fug_obt_pardinamico('ROL_DPTO_COM_EVALUACION'); -- DPTO_COM_EVALUACION
       end if;

       if fug_val_usu_rol('ROL_DPTO_RIE_EVALUACION', USER) then
          v_cod_rol := fug_obt_pardinamico('ROL_DPTO_RIE_EVALUACION'); -- DPTO_COM_EVALUACION
       end if;

       begin
          --**verificar si ya existe un registro para el nro. de solicitud y codigo de rol
          select count(*)
            into v_cantidad
            from ge_dat_rie_eva_intentos
           where nro_solicitud = p_nro_solicitud
             and cod_modulo = p_cod_modulo
             and cod_modalidad = p_cod_modalidad
             and cod_rol = v_cod_rol;

          --**si no existe el registro insertar uno nuevo
          if v_cantidad = 0 then
             insert
               into ge_dat_rie_eva_intentos
                    (nro_solicitud, can_intentos, cod_rol, cod_modulo, cod_modalidad)
             values (p_nro_solicitud, 1, v_cod_rol, p_cod_modulo, p_cod_modalidad);
          end if;

          --**si ya existe el registro actualizarlo
          if v_cantidad > 0 then
             update ge_dat_rie_eva_intentos
                set can_intentos = nvl(can_intentos, 0) + 1
              where nro_solicitud = p_nro_solicitud
                and cod_modulo = p_cod_modulo
                and cod_modalidad = p_cod_modalidad
                and cod_rol = v_cod_rol;
          end if;
       end;
    exception
       when others then
          pr_err_mensajes('Error en (PL_ACT_CAN_INTENTOS). ' || SQLERRM);
    end;
    -- Verifica que los campos obligatorios correspondientes a Informconf, Infocheck y BCP estén cargados.
    function fl_ver_cam_obl_antecedente(p_cod_persona IN ba_personas.cod_persona%TYPE)
       return BOOLEAN is

       cursor cu_ge_cli_antecedentes is
          select faj_buro, fec_ult_informconf, sit_infocheck, fec_ult_infocheck,
                 dispuesto, contingencia, pro_categoria,
                 med_dispuesto, fec_ult_crc, fec_crc,
                 mto_pag_minimo, dia_atraso, sit_tarjeta, fec_ult_bancard,
                 tot_deu_sistema, tot_deu_real, cat_sistema
            from ge_cli_antecedentes a
           where a.cod_persona = p_cod_persona;

    begin
       for ccu_ge_cli_antecedentes in cu_ge_cli_antecedentes loop
          --validar datos obligatorios de informconf
          if ccu_ge_cli_antecedentes.faj_buro is null then
             pr_err_mensajes('El campo Faja de Buró no puede quedar nulo! ');
          end if;

          --validar datos obligatorios de infocheck
          if ccu_ge_cli_antecedentes.sit_infocheck is null or ccu_ge_cli_antecedentes.fec_ult_infocheck is null then
             pr_err_mensajes('No todos los datos correspondientes a Infocheck han sido informados. Verifíquelos.! ');
          end if;

          --validar datos obligatorios de bancard
          if ccu_ge_cli_antecedentes.mto_pag_minimo is null or ccu_ge_cli_antecedentes.dia_atraso is null
             or ccu_ge_cli_antecedentes.sit_tarjeta is null or ccu_ge_cli_antecedentes.fec_ult_bancard is null then
             pr_err_mensajes('No todos los datos correspondientes a Bancard han sido informados. Verifíquelos.! ');
          end if;

          --validar datos de crc/bcp
          if ccu_ge_cli_antecedentes.tot_deu_sistema is null or ccu_ge_cli_antecedentes.tot_deu_real is null
             or ccu_ge_cli_antecedentes.dispuesto is null or ccu_ge_cli_antecedentes.contingencia is null
             or ccu_ge_cli_antecedentes.med_dispuesto is null or ccu_ge_cli_antecedentes.pro_categoria is null
             or ccu_ge_cli_antecedentes.cat_sistema is null or ccu_ge_cli_antecedentes.fec_ult_crc is null
             or ccu_ge_cli_antecedentes.fec_crc is null then
             pr_err_mensajes('No todos los datos correspondientes a CRC han sido informados. Verifíquelo! ');
          end if;

       end loop;
       return TRUE;
    exception
       when others then
          If sqlcode <= -20000 then
             raise;
          else
             raise_application_error(-20000, 'Error en (FL_VER_CAM_OBL_ANTECEDENTE). ' || SQLERRM);
          end if;
    end;
      -- Verifica si cumple las condiciones para informar o no al motor GMR
          Function FL_INF_CODEUDOR(PNRO_GARANTIA  In BA_PERSONAS.COD_PERSONA%Type,
                                   PNRO_SOLICITUD In PR_SOLICITUDES.NRO_SOLICITUD%Type)
               Return Boolean Is
               VCOD_MODALIDAD   GE_MODALIDADES.COD_MODALIDAD%Type;
               VCOD_PER_TITULAR BA_PERSONAS.COD_PERSONA%Type;
               VVINCULO         BA_VINCULOS.COD_PER_VINCULO%Type;
               VRETORNO         Boolean Default True;
               VSIN_SEPARACION  BA_PER_FISICAS.EST_CIVIL%Type;

          Begin
               --- Condiciones para no Informar al motor GMR ---
               -------------------------------------------------
               /*
                1 - Debe corresponder a las modalidades 686,687,681,676,673,612,610,609,604,68,65
                2 - El codedudor debe ser conyuge del titular
                3 - El codeudor debe estar casado con el titular sin separacion de bienes
               */
               --------------------------------------------------
               --OBTENGO LA MODALIDAD Y COD_PERSONA DEL TITULAR
               Begin
                    Select P.COD_MODALIDAD,
                           P.COD_PERSONA
                      Into VCOD_MODALIDAD,
                           VCOD_PER_TITULAR
                      From PR_SOLICITUDES P
                     Where P.NRO_SOLICITUD = PNRO_SOLICITUD;
               Exception
                    When Others Then
                         VCOD_MODALIDAD := Null;
               End;
               --VERIFICA QUE SEA DE LA MODALIDAD
               If instr(FUE_OBT_DES_REFCODES('MAD_CODEUDOR', VCOD_MODALIDAD),VCOD_MODALIDAD) <> 0 then --DYDMR-5118 - 30/09/2016
               /*If FUE_OBT_DES_REFCODES('MAD_CODEUDOR', VCOD_MODALIDAD) =
                  VCOD_MODALIDAD Then*/
                    --BUSCA EL COD_PER_VINCULO DEL CODEUDOR
                    Begin
                         Select NVL(V.COD_PER_VINCULO, 'X')
                           Into VVINCULO
                           From BA_VINCULOS V
                          Where V.TIPO = 'E' -- ESPOSO/A
                            And V.COD_PERSONA = PNRO_GARANTIA;
                    Exception
                         When Others Then
                              VVINCULO := 'X';
                    End;
                    --AHORA SE VERIFICA QUE SEA CONYUGE 'E' DEL TITULAR
                    If Trim(VCOD_PER_TITULAR) = Trim(VVINCULO) Then
                         -- SE OBTIENE EL ESTADO CIVIL DEL CODEUDOR
                         Begin
                              Select NVL(F.EST_CIVIL, 'X')
                                Into VSIN_SEPARACION
                                From BA_PER_FISICAS F
                               Where F.COD_PERSONA = PNRO_GARANTIA;
                         Exception
                              When Others Then
                                   VSIN_SEPARACION := 'X';
                         End;
                         --VERIFICAMOS QUE ESTE CASADO CON EL TITULAR SIN SEPARACION DE BIENES 'C'
                         If VSIN_SEPARACION = 'C' Then
                              VRETORNO := False;
                         End If;
                    End If;
               else
                  raise_application_error(-20000, 'Error en FUE_OBT_DES_REFCODES modalidad '||VCOD_MODALIDAD||' no esta parametrizada para CODEUDOR). ' || SQLERRM);
               End If;
               Return VRETORNO;
          Exception
               When Others Then
                    --Null;
                    pr_err_mensajes('Error en FUE_OBT_DES_REFCODES modalidad '||VCOD_MODALIDAD||' no esta parametrizada para CODEUDOR). ' || SQLERRM);--DYDMR-5118 - Nov/2016
          End;
    -- DYDMR-5927 NAF 01/2017 valida datos numericos de scoring
    function fl_val_dat_numerico(p_cadena   varchar2,
                               p_lon_num     IN number,
                               p_lon_dec     IN number,
                               p_sep_dec     IN varchar2 default '.')
      RETURN NUMBER IS
      v_ret_principal        NUMBER(30,20) := 0;
      v_numero               number := 0;
      v_decimal              number := 0;
      v_pos_dec              number := 0;
    BEGIN
      v_pos_dec := INSTR(TRIM(p_cadena),p_sep_dec);
      v_numero  := substr(TRIM(p_cadena),1,v_pos_dec-1);
      v_decimal := substr(TRIM(p_cadena),v_pos_dec+1);
      v_decimal := substr(v_decimal,1,p_lon_dec);

      v_ret_principal := to_number( v_numero || p_sep_dec || v_decimal,
                           lPAD('9',p_lon_num,'9') || 'D' || lPAD('0',p_lon_dec,'0'),
                           'nls_numeric_characters=''' || p_sep_dec || ' ''');

      RETURN v_ret_principal;
    END;

  BEGIN
    -- Control de Cantidad de Intentos por Usuario
    pl_ver_rol_can_intentos(p_nro_solicitud, p_cod_modulo, p_cod_modalidad); -- DYDMR-47. CB. 06/03/2014.

    --Verifico si es Pre-Aprobado
    BEGIN
      SELECT 'S'
        INTO v_pre_aprobado
        FROM pr_solicitudes p, ge_pro_pre_aprobados a
       WHERE p.nro_solicitud = a.nro_solicitud
         AND p.nro_solicitud = p_nro_solicitud
         AND p.cod_modulo = p_cod_modulo
         AND p.cod_modalidad = p_cod_modalidad
         /*dydmr-2027 fm 30/06/2015*/
         and p.cod_modulo = a.cod_modulo
         and p.cod_modalidad = a.cod_modalidad
      UNION ALL
      SELECT 'S'
        FROM ta_solicitudes t, ge_pro_pre_aprobados a
       WHERE t.nro_solicitud = a.nro_solicitud
         AND t.nro_solicitud = p_nro_solicitud
         AND t.cod_modulo = p_cod_modulo
         AND t.cod_modalidad = p_cod_modalidad
         /*dydmr-2027 fm*/
         and t.cod_modulo = a.cod_modulo
         and t.cod_modalidad = a.cod_modalidad;
    EXCEPTION
      WHEN no_data_found THEN
        v_pre_aprobado := 'N';
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar Pre-Aprobado (PR_SOLICITUDES). ' ||
                        SQLERRM);
    END;
    --Obtengo Datos de la Solicitud
    BEGIN
      SELECT nvl(estado, 'X'),
             nvl(est_verificacion, 'X'),
             cod_modulo,
             cod_modalidad,
             cod_persona,
             cod_moneda,
             mto_interes,
             monto,
             dia_plazo,
             tipo,
             nro_linea,
             cod_campana
        INTO v_estado,
             v_est_verificacion,
             v_cod_modulo,
             v_cod_modalidad,
             v_cod_persona,
             v_cod_moneda,
             v_mto_interes,
             v_monto,
             v_dia_plazo,
             v_tip_prestamo,
             v_lin_credito,
             v_cod_campana
        FROM pr_solicitudes
       WHERE nro_solicitud = p_nro_solicitud
         AND cod_modulo = p_cod_modulo
         AND cod_modalidad = p_cod_modalidad
      UNION ALL
      SELECT 'X',
             'X',
             cod_modulo,
             cod_modalidad,
             cod_persona,
             cod_moneda,
             0,
             monto,
             0,
             'A',
             nro_linea,
             cod_campana
        FROM ta_solicitudes
       WHERE nro_solicitud = p_nro_solicitud
         AND cod_modulo = p_cod_modulo
         AND cod_modalidad = p_cod_modalidad
      UNION ALL
      SELECT 'X',
             'X',
             t.cod_modulo,
             t.cod_modalidad,
             a.cod_persona,
             a.cod_moneda,
             0,
             a.lin_credito,
             0,
             'A',
             t.nro_linea,
             a.cod_campana
        FROM ta_sol_lineas a, ta_cta_tarjetas t
       WHERE a.nro_solicitud = p_nro_solicitud
         AND a.tip_solicitud = 'A'
         AND t.cod_modulo = p_cod_modulo
         AND t.cod_modalidad = p_cod_modalidad
         AND t.nro_cuenta = a.nro_cuenta;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('Solicitud Inexistente.');
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (PR_SOLICITUDES). ' || SQLERRM);
    END;
    --Verifico Parámetro Dinámico de Modalidades Definidas para el control.
    v_par_dinamico := nvl(fug_obt_pardinamico('SOL_MAD_VERIFICACIONES',
                                              v_cod_modulo,
                                              v_cod_modalidad),
                          'N');
    --Realizo la Evaluación sólo para los Módulos y Modalidades definidas.
    IF v_par_dinamico = 'S' THEN
      IF p_cod_modulo = 6 THEN
        --Controlar Estado de Línea de Crédito
        IF v_lin_credito IS NOT NULL THEN
          BEGIN
            SELECT nvl(estado, 'X')
              INTO v_est_linea
              FROM pr_lineas
             WHERE nro_linea = v_lin_credito;
          EXCEPTION
            WHEN no_data_found THEN
              pr_err_mensajes('Línea de Crédito ' || v_lin_credito ||
                              ' no existe.');
            WHEN OTHERS THEN
              pr_err_mensajes('Error al consultar (PR_LINEAS). ' ||
                              SQLERRM);
          END;
        END IF;
        --Si fuera Pre-Aprobado y el Estado no es Pend.Liquidacion
        IF v_pre_aprobado = 'S' AND v_estado <> 'L' THEN
          pr_err_mensajes('Estado de Solicitud de Pre-Aprobado debe ser Pendiente de Liquidación.');
          --Si no fuera Pre-Aprobado y el Estado no es Solicitada y no tiene Línea de Crédito
        ELSIF (v_pre_aprobado = 'N' AND v_lin_credito IS NULL AND
              v_estado <> 'S') THEN
          pr_err_mensajes('Estado de Solicitud debe ser Solicitada.');
          --Si no fuera Pre-Aprobado y el Estado no es Pend.Liquidacion y tiene Línea de Crédito
        ELSIF (v_pre_aprobado = 'N' AND v_lin_credito IS NOT NULL AND
              v_est_linea = 'A' AND v_estado <> 'L') THEN
          pr_err_mensajes('La Propuesta tiene Línea de Crédito Aprobada. Estado de Solicitud debe ser Pendiente de Liquidación.');
        END IF;
        --Si la Solicitud no estuviera Verificada
        IF v_est_verificacion <> 'S' THEN
          pr_err_mensajes('Estado de Verificación de Solicitud no corresponde.');
        END IF;
      END IF;
      --Verificar Consultas de Informconf e Infocheck
      BEGIN
        SELECT a.fec_ult_informconf, a.fec_ult_infocheck
          INTO v_fec_informconf, v_fec_infocheck
          FROM ge_cli_antecedentes a
         WHERE a.cod_persona = v_cod_persona;
      EXCEPTION
        WHEN no_data_found THEN
          pr_err_mensajes('Primero debe Consultar los datos de Informconf e Infocheck.');
        WHEN OTHERS THEN
          pr_err_mensajes('Error al consultar (GE_CLI_ANTECEDENTES). ' ||
                          SQLERRM);
      END;
      IF v_fec_informconf IS NULL THEN
        pr_err_mensajes('Primero debe Consultar los datos de Informconf.');
      END IF;
      IF v_fec_infocheck IS NULL THEN
        pr_err_mensajes('Primero debe Consultar los datos de Infocheck.');
      END IF;

       v_dat_obligatorios:= fl_ver_cam_obl_antecedente(v_cod_persona);

      --Busco valor para NRO_INTENTO
      BEGIN
        SELECT nvl(MAX(nro_intento), 0) + 1
          INTO v_intento
          FROM ge_dat_rie_evaluaciones
         WHERE nro_solicitud = p_nro_solicitud
           AND cod_modulo = p_cod_modulo
           AND cod_modalidad = p_cod_modalidad;
      EXCEPTION
        WHEN no_data_found THEN
          v_intento := 1;
        WHEN OTHERS THEN
          pr_err_mensajes('Error al consultar max(intento) (GE_DAT_RIE_EVALUACIONES). ' ||
                          SQLERRM);
      END;
      --Obtengo valor para campo COD_FLUJO
      v_flujo := nvl(lpad(TRIM(nvl(fug_obt_pardinamico('COD_FLU_EVALUACION',
                                                       v_cod_modulo,
                                                       v_cod_modalidad),
                                   fug_obt_pardinamico('COD_FLU_CONSUMO',
                                                       v_cod_modulo))),
                          10,
                          '0'),
                     '0000000000');
      --Inserto los datos obtenidos
      v_version   := nvl(lpad(TRIM(fug_obt_pardinamico('COD_FLU_EVA_VERSION')),
                              4,
                              '0'),
                         '0000');
      v_reservado := '00'; --siempre se informa con valor '00'
      v_nivel     := 1; --siempre se informa con valor 1

     --Obtengo Persona Vinculada
      BEGIN
        SELECT b.cod_per_vinculo
          INTO v_cod_per_vinculo
          FROM ba_vinculos b
         WHERE b.cod_persona = v_cod_persona
           AND b.tipo = 'E';
      EXCEPTION
        WHEN no_data_found THEN
            BEGIN
              SELECT b.cod_per_vinculo
                INTO v_cod_per_vinculo
                FROM ba_vinculos b
               WHERE b.cod_persona = v_cod_persona
                 AND b.tipo = 'C';
            EXCEPTION
              WHEN no_data_found THEN
                v_cod_per_vinculo := NULL;
            END;
      END;
      --Armar cadena de Intervinientes
      v_intervinientes := '(P)' || v_cod_persona;
      --Armar la cadena correspondiente al cónyuge
      IF v_cod_per_vinculo IS NOT NULL AND p_cod_modulo = 6 THEN
        v_cad_conyuge    := fl_obt_cad_personas(v_cod_per_vinculo, 'Y');
        v_intervinientes := v_intervinientes || ',' || '(Y)' ||
                            v_cod_per_vinculo;
      END IF;
      V_CODEUDOR := 'N';
      --Armar la cadena correspondiente a los codeudores
      IF p_cod_modulo = 6 THEN
         FOR i IN codeudores LOOP
            V_CODEUDOR := 'S';
           --Controla que el codeudor no sea conyugue para informar
           If FL_INF_CODEUDOR(I.NRO_GARANTIA, I.NRO_SOLICITUD) Then
              v_cad_codeudor   := fl_obt_cad_personas(i.nro_garantia, 'C');
              v_cad_codeudores := v_cad_codeudores || v_cad_codeudor;
              v_intervinientes := v_intervinientes || ',' || '(C)' || i.nro_garantia;
               V_CODEUDOR       := 'N';
           End If;
         END LOOP;
      ELSIF p_cod_modulo = 5 THEN
         FOR i IN tar_codeudores LOOP
           v_cad_codeudor   := fl_obt_cad_personas(i.nro_garantia, 'C');
           v_cad_codeudores := v_cad_codeudores || v_cad_codeudor;
           v_intervinientes := v_intervinientes || ',' || '(C)' || i.nro_garantia;
         END LOOP;
      END IF;
      --Armar cadena de la Operación
               V_CAD_OPERACION := V_FLUJO || V_VERSION || V_RESERVADO ||
                                  V_NIVEL || LPAD(P_NRO_SOLICITUD, 7, '0') ||
                                  FL_OBT_CAD_OPERACION(P_NRO_SOLICITUD,
                                                       P_COD_MODULO,
                                                       P_COD_MODALIDAD,
                                                       V_CODEUDOR);
               V_CAD_PRINCIPAL := FL_OBT_CAD_PERSONAS(V_COD_PERSONA, 'P');
               V_CAD_PRINCIPAL := V_CAD_OPERACION || V_CAD_PRINCIPAL;

      --Termina cadena de Intervinientes
      v_intervinientes := 'Verificar Intervinientes (' || v_intervinientes || ')';
      --Llama al socket
      v_dat_entrada := v_cad_principal || v_cad_conyuge || v_cad_codeudores;
      v_ok          := fue_env_tcp_mensajes(v_servidor,
                                            v_puerto,
                                            v_tie_espera,
                                            v_dat_entrada,
                                            v_respuesta);
      -- DYDMR-5076 Oct/2016 NAF - Almacena log respuesta scoring
      prg_act_log_procesos('PAR_PER.PR_GEN_RIE_EVALUACIONES',p_nro_solicitud, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), '00:00:01',substr(v_respuesta,1,400));
      prg_act_log_procesos('PAR_PER.PR_GEN_RIE_EVALUACIONES',p_nro_solicitud, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), '00:00:02',substr(v_respuesta,401,400));

      IF v_ok != 'S' THEN
        pr_err_mensajes('Error en el Socket. ' || v_respuesta);
      ELSE
        IF substr(v_respuesta, 1, 2) = '00' THEN
          --Control de Dictamen Final (7- No Evaluado), se considera como error
          IF TRIM(substr(v_respuesta, 12, 1)) = 7 THEN
            --Se busca el mensaje del campo Alerta
            v_respuesta := 'AL' ||
                           TRIM(substr(v_respuesta,
                                       length(v_respuesta) - 98));
            --Retorna Respuesta de Alerta por Dictamen Final 7
            p_mensaje := v_respuesta;
            --Indica que el estado de verificacion de la solicitud se actualice a N.
            v_act_est_verificacion := 'S';
          ELSE
            --Asigno valor a variable de retorno
            p_nro_intento := v_intento;
            --Se insertan los registros si la respuesta del socket es correcta
            ------------------------------------------------------------------
            BEGIN
              --Inserto Datos Cabecera
              INSERT INTO ge_dat_rie_evaluaciones
                (nro_solicitud,
                 nro_intento,
                 cod_persona,
                 cod_modulo,
                 cod_modalidad,
                 cod_flujo,
                 ver_flujo,
                 reservado,
                 nivel)
              VALUES
                (p_nro_solicitud,
                 v_intento,
                 v_cod_persona,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_flujo,
                 v_version,
                 v_reservado,
                 v_nivel);
              --Inserto Datos Detalle del Principal
              INSERT INTO ge_dat_rie_evaluaciones_det
                (nro_solicitud,
                 nro_intento,
                 nro_secuencia,
                 tip_rel_persona,
                 cod_persona,
                 dat_entrada,
                 cod_modulo,
                 cod_modalidad)
              VALUES
                (p_nro_solicitud,
                 v_intento,
                 v_nro_secuencia,
                 'P',
                 v_cod_persona,
                 v_cad_principal,
                 v_cod_modulo,
                 v_cod_modalidad);
              --Inserto Datos Detalle Cónyuge
              IF v_cod_per_vinculo IS NOT NULL THEN
                v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
                v_cad_conyuge   := fl_obt_cad_personas(v_cod_per_vinculo,
                                                       'Y');
                INSERT INTO ge_dat_rie_evaluaciones_det
                  (nro_solicitud,
                   nro_intento,
                   nro_secuencia,
                   tip_rel_persona,
                   cod_persona,
                   dat_entrada,
                   cod_modulo,
                   cod_modalidad)
                VALUES
                  (p_nro_solicitud,
                   v_intento,
                   v_nro_secuencia,
                   'Y',
                   v_cod_per_vinculo,
                   v_cad_conyuge,
                   v_cod_modulo,
                   v_cod_modalidad);
                v_can_personas := v_can_personas + 1;
              END IF;
              IF p_cod_modulo = 6 THEN
                 --Inserto Detalle de los Co-Deudores
                 FOR i IN codeudores LOOP
                    v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
                    v_cad_codeudor  := fl_obt_cad_personas(i.nro_garantia, 'C');
                    INSERT INTO ge_dat_rie_evaluaciones_det
                        (nro_solicitud,
                        nro_intento,
                        nro_secuencia,
                        tip_rel_persona,
                        cod_persona,
                        dat_entrada,
                        cod_modulo,
                        cod_modalidad)
                    VALUES
                       (p_nro_solicitud,
                       v_intento,
                       v_nro_secuencia,
                       'C',
                       i.nro_garantia,
                       v_cad_codeudor,
                       v_cod_modulo,
                       v_cod_modalidad);
                    v_cad_codeudores := v_cad_codeudores || v_cad_codeudor;
                    v_can_personas   := v_can_personas + 1;
                 END LOOP;
                 -- Se ejecuta procedimiento interno PL_ACT_CAN_INTENTOS.
                 pl_act_can_intentos(p_nro_solicitud, p_cod_modulo, p_cod_modalidad);
              ELSIF p_cod_modulo = 5 THEN
                 --Inserto Detalle de los Co-Deudores solicitudes de tarjetas
                 FOR i IN tar_codeudores LOOP
                    v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
                    v_cad_codeudor  := fl_obt_cad_personas(i.nro_garantia, 'C');
                    INSERT INTO ge_dat_rie_evaluaciones_det
                       (nro_solicitud,
                       nro_intento,
                       nro_secuencia,
                       tip_rel_persona,
                       cod_persona,
                       dat_entrada,
                       cod_modulo,
                       cod_modalidad)
                    VALUES
                       (p_nro_solicitud,
                       v_intento,
                       v_nro_secuencia,
                       'C',
                       i.nro_garantia,
                       v_cad_codeudor,
                       v_cod_modulo,
                       v_cod_modalidad);

                    v_cad_codeudores := v_cad_codeudores || v_cad_codeudor;
                    v_can_personas   := v_can_personas + 1;
                 END LOOP;
                 -- Se ejecuta procedimiento interno PL_ACT_CAN_INTENTOS.
                 pl_act_can_intentos(p_nro_solicitud, p_cod_modulo, p_cod_modalidad);
              END IF;

              --Se Actualizan los registros según la respuesta del socket
              -----------------------------------------------------------
              --Actualizo Datos Cabecera
              UPDATE ge_dat_rie_evaluaciones a
                 SET a.dic_per_final       = TRIM(substr(v_respuesta, 10, 1)),
                     a.dic_bur_final       = TRIM(substr(v_respuesta, 11, 1)),
                     a.dic_final           = TRIM(substr(v_respuesta, 12, 1)),
                     a.mto_reconducido     = to_number(TRIM(REPLACE(substr(v_respuesta,
                                                                   13,
                                                                   18),',','.')), '999999999999999999D00', 'nls_numeric_characters=''. '''), -- DYDMR-5076 Oct/2016 NAF
                     a.plazo               = to_number(TRIM(REPLACE(substr(v_respuesta,
                                                                   31,
                                                                   4),',','.')), '9999', 'nls_numeric_characters=''. '''),
                     a.tas_mto_reconducido = to_number(TRIM(REPLACE(substr(v_respuesta,
                                                                   35,
                                                                   5),',','.')), '99999D00', 'nls_numeric_characters=''. '''),
                     a.lim_max_operacion   = to_number(TRIM(REPLACE(substr(v_respuesta,
                                                                   40,
                                                                   18),',','.')), '999999999999999999D00', 'nls_numeric_characters=''. '''),
                     a.cod_moneda          = TRIM(substr(v_respuesta, 58, 3)),
                     a.estado              = 'E'
               WHERE a.nro_solicitud = p_nro_solicitud
                 AND a.nro_intento = v_intento
                 AND a.cod_persona = v_cod_persona
                 AND a.cod_modulo = v_cod_modulo
                 AND a.cod_modalidad = v_cod_modalidad;
              --Actualizo Datos Detalle del Principal
              v_pun_scoring := fl_val_dat_numerico(TRIM(REPLACE(substr(v_respuesta,
                                                               91,
                                                               18),',','.')),17,9);
              v_cuota := substr(v_respuesta, 61, 20);
              UPDATE ge_dat_rie_evaluaciones_det g
                 SET g.pun_scoring     = v_pun_scoring, -- DYDMR-5927 Ene/2017 NAF
                     g.pro_mora        = to_number(TRIM(REPLACE(substr(v_respuesta,
                                                               109,
                                                               5),',','.')), '99999D00', 'nls_numeric_characters=''. '''), -- DYDMR-5076 Oct/2016 NAF

                     g.dic_perfil      = TRIM(substr(v_respuesta, 114, 1)),
                     g.bal_caja        = to_number(TRIM(REPLACE(substr(v_respuesta,
                                                               115,
                                                               18),',','.')), '999999999999999999D00', 'nls_numeric_characters=''. '''),

                     g.dic_bal_caja    = TRIM(substr(v_respuesta, 133, 1)),
                     g.dic_buro        = TRIM(substr(v_respuesta, 134, 1)),
                     g.lim_max_persona = to_number(TRIM(REPLACE(substr(v_respuesta,
                                                               135,
                                                               18),',','.')), '999999999999999999D00', 'nls_numeric_characters=''. '''),
                     g.val_alertas     = TRIM(substr(v_respuesta, 155, v_can_alertas)),
                     g.montos          = substr(v_respuesta, 155 + v_can_alertas, 320)||v_cuota
               WHERE g.nro_solicitud = to_number(TRIM(substr(v_respuesta, 3, 7)))
                 AND g.nro_intento = v_intento
                 AND g.tip_rel_persona = 'P'
                 AND g.cod_persona = TRIM(substr(v_respuesta, 81, 10))
                 AND g.cod_modulo = v_cod_modulo
                 AND g.cod_modalidad = v_cod_modalidad;
              --Actualizo Detalle solo si tiene personas vinculadas
              IF v_can_personas > 0 THEN
                v_posicion := 155 + v_can_alertas + 320; --indica la última posición del detalle principal
                FOR i IN 1 .. v_can_personas LOOP
                  rg_evaluaciones_det.cod_persona     := TRIM(substr(v_respuesta,
                                                                     v_posicion,
                                                                     10));
                  v_posicion                          := v_posicion + 10;
                  rg_evaluaciones_det.pun_scoring     := fl_val_dat_numerico(TRIM(REPLACE(substr(v_respuesta,
                                                                               v_posicion,
                                                                               18),',','.')), 17, 9); -- DYDMR-5927 Ene/2017 NAF
                  v_posicion                          := v_posicion + 18;
                  rg_evaluaciones_det.pro_mora        := to_number(TRIM(REPLACE(substr(v_respuesta,
                                                                               v_posicion,
                                                                               5),',','.')), '99999D00', 'nls_numeric_characters=''. ''');
                  v_posicion                          := v_posicion + 5;
                  rg_evaluaciones_det.dic_perfil      := TRIM(substr(v_respuesta,
                                                                     v_posicion,
                                                                     1));
                  v_posicion                          := v_posicion + 1;
                  rg_evaluaciones_det.bal_caja        := to_number(TRIM(REPLACE(substr(v_respuesta,
                                                                               v_posicion,
                                                                               18),',','.')), '999999999999999999D00', 'nls_numeric_characters=''. ''');
                  v_posicion                          := v_posicion + 18;
                  rg_evaluaciones_det.dic_bal_caja    := TRIM(substr(v_respuesta,
                                                                     v_posicion,
                                                                     1));
                  v_posicion                          := v_posicion + 1;
                  rg_evaluaciones_det.dic_buro        := TRIM(substr(v_respuesta,
                                                                     v_posicion,
                                                                     1));
                  v_posicion                          := v_posicion + 1;
                  rg_evaluaciones_det.lim_max_persona := to_number(TRIM(REPLACE(substr(v_respuesta,
                                                                               v_posicion,
                                                                               18),',','.')), '999999999999999999D00', 'nls_numeric_characters=''. ''');
                  v_posicion                          := v_posicion + 18;
                  rg_evaluaciones_det.tip_rel_persona := TRIM(substr(v_respuesta,
                                                                     v_posicion,
                                                                     1));
                  v_posicion                          := v_posicion + 1;
                  rg_evaluaciones_det.val_alertas     := TRIM(substr(v_respuesta,
                                                                     v_posicion + 1,
                                                                     v_can_alertas));
                  v_posicion                          := v_posicion +  v_can_alertas + 1;
                  rg_evaluaciones_det.montos          := substr(v_respuesta,
                                                                v_posicion,
                                                                320)||v_cuota;
                  --Actualizo Datos Detalle Vinculados
                  UPDATE ge_dat_rie_evaluaciones_det g
                     SET g.pun_scoring     = rg_evaluaciones_det.pun_scoring,
                         g.pro_mora        = rg_evaluaciones_det.pro_mora,
                         g.dic_perfil      = rg_evaluaciones_det.dic_perfil,
                         g.bal_caja        = rg_evaluaciones_det.bal_caja,
                         g.dic_bal_caja    = rg_evaluaciones_det.dic_bal_caja,
                         g.dic_buro        = rg_evaluaciones_det.dic_buro,
                         g.lim_max_persona = rg_evaluaciones_det.lim_max_persona,
                         g.val_alertas     = rg_evaluaciones_det.val_alertas,
                         g.montos          = rg_evaluaciones_det.montos
                   WHERE g.nro_solicitud = to_number(TRIM(substr(v_respuesta, 3, 7)))
                     AND g.nro_intento = v_intento
                     AND g.tip_rel_persona =
                         rg_evaluaciones_det.tip_rel_persona
                     AND g.cod_persona = rg_evaluaciones_det.cod_persona
                     AND g.cod_modulo = v_cod_modulo
                     AND g.cod_modalidad = v_cod_modalidad;
                  v_posicion := v_posicion + 320;
                END LOOP;
              END IF;
            EXCEPTION
              WHEN OTHERS THEN
                -- DYDMR-5076 Oct/2016 NAF - Almacena log mensaje de error
                prg_act_log_procesos('PAR_PER.PR_GEN_RIE_EVALUACIONES',p_nro_solicitud, trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), '00:00:00',substr(SQLERRM,1,400));
                pr_err_mensajes(SQLERRM);
            END;
            --Retorna Respuesta si todo fue OK
            p_mensaje := v_respuesta;
          END IF;
        ELSE
          --Retorna Respuesta por Error + Lista de Intervinientes
          p_mensaje := v_respuesta || ' ' || v_intervinientes;
          --Indica que el estado de verificacion de la solicitud se actualice a N.
          v_act_est_verificacion := 'S';
        END IF;
      END IF;
    ELSE
      --Retorna Respuesta por Modalidad no definida en Parámetro Dinámico
      p_mensaje := 'Modalidad no definida';
    END IF;
    --Actualizo estado de las solicitudes de tarjetas de tipo pre-aprobado y con ind_evaluacion ='S'
    IF p_cod_modulo = 5 AND v_pre_aprobado = 'S' AND v_act_est_verificacion <> 'S'then
       UPDATE ta_solicitudes a
          SET a.cod_estado     = 'APR',
              a.fec_aprobacion = pag_cal.fu_obt_fec_actual(5),
              a.mto_aprobado   = v_monto
        WHERE  a.nro_solicitud = p_nro_solicitud;
       --Actualizo el estado del pre-aprobado asignado porque ya terminó la operación con esta solicitud.
       pr_act_pre_aprobado(p_nro_solicitud, v_cod_persona,p_cod_modulo,p_cod_modalidad);
    END IF;
    --Actualizo estado de verificación de la Solicitud cuando el motor retorne Error o Dictamen Final No-Evaluado
    IF v_act_est_verificacion = 'S' AND v_estado = 'S' THEN
      UPDATE pr_solicitudes a
         SET a.est_verificacion = 'N'
       WHERE a.nro_solicitud = p_nro_solicitud;
    END IF;
  END;
  PROCEDURE pr_act_pre_aprobado( p_nro_solicitud IN ge_pro_pre_aprobados.nro_solicitud%TYPE,
                                 p_cod_persona   IN ge_pro_pre_aprobados.cod_persona%TYPE,
                                 p_cod_modulo    IN ge_pro_pre_aprobados.cod_modulo%TYPE,
                                 p_cod_modalidad IN ge_pro_pre_aprobados.cod_modalidad%TYPE,
                         p_cod_sub_modalidad IN ge_pro_pre_aprobados.cod_sub_modalidad%TYPE default null) -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- CN: 10/2016 --
         IS
     v_exi_par_dinamico   ge_parametros.parametro%type;
     v_tie_sub_modalidad  varchar2(10);
     v_sol_vinculada      varchar2(1);
  BEGIN
   ---DYDMR-7139 - Incidencia SAU - ITGF - Desembolso de préstamo - Error
   BEGIN
     select distinct 'S'
       into v_sol_vinculada
       from ge_pro_pre_aprobados
      where nro_solicitud = p_nro_solicitud
        and cod_persona = p_cod_persona;
   EXCEPTION
     WHEN TOO_MANY_ROWS THEN
       v_sol_vinculada := 'S';
     WHEN NO_DATA_FOUND THEN
       v_sol_vinculada := 'N';
     WHEN OTHERS THEN
       v_sol_vinculada := 'N';
   END;
  ---DYDMR-7139 - Incidencia SAU - ITGF - Desembolso de préstamo - Error
  If (nvl(v_sol_vinculada, 'N') = 'N')   --Inicio Sol_vinculada
     --DYDMR-7239) Incidencia SAU - ITGF - Cancelación Préstamos Preaprobados HB
     or (user = 'HBANK' ) OR (user like '%ATM%')  then

     SELECT fug_obt_pardinamico('COD_CAU_PRE_APROBADO',p_cod_modulo,p_cod_modalidad,p_cod_sub_modalidad) -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- CN: 10/2016 --
       INTO v_exi_par_dinamico
       FROM DUAL;
     IF v_exi_par_dinamico IS NULL THEN
        pr_err_mensajes('Primero debe Asignar un valor al Parámetro Dinámico COD_CAU_PRE_APROBADO.');
     ELSE

     --08/05/2017 Buscamos si ya tiene sub-modalidad
      v_tie_sub_modalidad:='N';
      begin
       select 'S'
        into v_tie_sub_modalidad
         from ge_pro_pre_aprobados a
           WHERE cod_persona = p_cod_persona
           AND (  (cod_modulo = p_cod_modulo AND cod_modalidad IS NULL) --módulo 5 tarjetas
                 OR ( cod_modulo = p_cod_modulo AND cod_modalidad = p_cod_modalidad) --módulo 6 préstamos
                )      -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- CN: 10/2016 --
           AND estado = 'V'
           AND (nro_solicitud IS NULL or (cod_modalidad = 68 and nro_solicitud is not null))
           and a.cod_sub_modalidad is not null;
      exception
       when no_data_found then
         v_tie_sub_modalidad:='N';
       when others then
         v_tie_sub_modalidad:='N';
      end;

      if v_tie_sub_modalidad='N' then
        --Actualizo el estado del pre-aprobado.
        UPDATE ge_pro_pre_aprobados
           SET estado = 'C',
               cod_causa = v_exi_par_dinamico,
               cod_usu_cancelacion = upper(user),
               nro_solicitud = p_nro_solicitud,
               cod_modalidad = p_cod_modalidad,
               cod_sub_modalidad = null -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- CN: 10/2016 --
         WHERE cod_persona = p_cod_persona
           AND (  (cod_modulo = p_cod_modulo AND cod_modalidad IS NULL) --módulo 5 tarjetas
                 OR ( cod_modulo = p_cod_modulo AND cod_modalidad = p_cod_modalidad) --módulo 6 préstamos
                )      -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- CN: 10/2016 --
           AND estado = 'V'
           AND (nro_solicitud IS NULL or (cod_modalidad = 68 and nro_solicitud is not null));
      else
        --Actualizo el estado del pre-aprobado.
        UPDATE ge_pro_pre_aprobados
           SET estado = 'C',
               cod_causa = v_exi_par_dinamico,
               cod_usu_cancelacion = upper(user),
               nro_solicitud = p_nro_solicitud,
               cod_modalidad = p_cod_modalidad,
               cod_sub_modalidad = p_cod_sub_modalidad -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- CN: 10/2016 --
         WHERE cod_persona = p_cod_persona
           AND (  (cod_modulo = p_cod_modulo AND cod_modalidad IS NULL) --módulo 5 tarjetas
                 OR ( cod_modulo = p_cod_modulo AND cod_modalidad = p_cod_modalidad
                    AND (nvl(cod_sub_modalidad,p_cod_sub_modalidad) = p_cod_sub_modalidad OR p_cod_sub_modalidad is null)) --módulo 6 préstamos
                )      -- PCCFPPTC-1 -- Flexibilidad en módulo Preaprobados de Consumo y TDC en el Core -- CN: 10/2016 --
           AND estado = 'V'
           AND (nro_solicitud IS NULL or (cod_modalidad = 68 and nro_solicitud is not null));
      end if;
     END IF;
    End if;--Fin Sol_vinculada
  EXCEPTION
     WHEN OTHERS THEN
        pr_err_mensajes('Error al Actualizar el Producto Pre-Aprobado. ' || SQLERRM);
  END;

  FUNCTION fu_val_dat_segmentacion(p_cod_persona    IN ba_personas.cod_persona%TYPE,
                                   p_cod_modulo     IN ba_modulos.cod_modulo%TYPE,
                                   p_cod_modalidad  IN ge_modalidades.cod_modalidad%TYPE,
                                   p_mto_solicitud  IN pr_solicitudes.monto%TYPE)
    RETURN BOOLEAN IS
    v_tipo                ba_personas.tipo%TYPE;
    v_cod_tip_actividad   ge_cam_obl_segmentacion.cod_tip_actividad%type;
    v_plz_vigencia        ge_cam_obl_segmentacion.plz_vigencia%type := 0;
    v_plz_vig_facturacion ge_cam_obl_segmentacion.plz_vigencia%type := fug_obt_pardinamico('CRM_PLZ_FACTURACION');
    v_plz_vig_rating      ge_cam_obl_segmentacion.plz_vigencia%type := fug_obt_pardinamico('CRM_PLZ_FAC_DAT_RATING');
    v_cod_act_primaria    ge_cam_obl_segmentacion.cod_rub_primario%type;
    v_anho                cr_per_dat_segmentacion.ano_facturacion%type;
    v_mes                 cr_per_dat_segmentacion.mes_facturacion%type;
    v_estado              cr_per_dat_segmentacion.estado%type;
    v_mes_rating          cr_per_dat_segmentacion.mes_rating%type;
    v_ano_rating          cr_per_dat_segmentacion.ano_rating%type;
    v_mto_facturacion     cr_per_dat_segmentacion.mto_facturacion%type := 0;
    v_mto_rating          cr_per_dat_segmentacion.mto_facturacion%type := fug_obt_pardinamico('CRM_MTO_FAC_DAT_RATING');
    v_mes_hatos           cr_per_dat_segmentacion.mes_facturacion%type;
    v_ano_hatos           cr_per_dat_segmentacion.ano_facturacion%type;
    v_can_hatos           cr_per_dat_segmentacion.can_hatos%type := 0;
    v_mandatorio          ge_cam_obl_segmentacion.mandatorio%type := 'N';
    v_fec_plz_vigencia    DATE;
    v_fec_plz_rating      DATE;
    v_fec_plz_hatos       DATE;
    v_fec_plz_hectareas   DATE;
    v_fec_actual          DATE := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_control             NUMBER := 0;
    v_ins_registro        VARCHAR2(1) := 'N';
    v_tip_hectarea        VARCHAR2(60) := NULL;
    -- Verificación de datos mandatorios PJ.
    v_naturaleza          ba_per_juridicas.naturaleza%type := NULL;
    v_fec_constitucion    ba_per_juridicas.fec_apertura%type := NULL;
    v_can_empleados       ba_per_juridicas.can_empleados%type := NULL;
    v_can_sucursales      ba_per_juridicas.can_sucursales%type := NULL;
    --procedimiento local
    PROCEDURE lp_eli_tmp_tablas(p_cod_persona in ba_personas.cod_persona%type) is
    PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
      --Borro la verificación anterior de la persona
      DELETE FROM ge_sol_ver_personas_det_tmp a
       WHERE a.cod_persona = p_cod_persona;
      DELETE FROM ge_sol_ver_personas_tmp a
       WHERE a.cod_persona = p_cod_persona;
      commit;
   END lp_eli_tmp_tablas;
BEGIN
    IF p_cod_persona IS NULL THEN
      pr_err_mensajes('Código de Persona es requerido.');
    END IF;
    IF p_cod_modulo IS NULL THEN
      pr_err_mensajes('Código de Módulo es requerido.');
    END IF;
    IF p_cod_modalidad IS NULL THEN
      pr_err_mensajes('Código de Modalidad es requerido.');
    END IF;

    --Inicializo variables globales
    g_cod_persona   := p_cod_persona;
    g_cod_modulo    := p_cod_modulo;
    g_cod_modalidad := p_cod_modalidad;
    g_mto_solicitud := p_mto_solicitud;

    --Verifico que la persona sea de Tipo Física
    BEGIN
      SELECT a.tipo
        INTO v_tipo
        FROM ba_personas a
       WHERE a.cod_persona = g_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('Persona no definida en (BA_PERSONAS).');
      WHEN OTHERS THEN
        pr_err_mensajes('Error al consultar (BA_PERSONAS). ' || SQLERRM);
    END;

    -- Verifico las modalidades excluyentes.
    IF fug_obt_pardinamico('COD_MOD_EXC_SEGMENTACION',g_cod_modulo, g_cod_modalidad) = 'S' THEN
       RAISE salir;
    END IF;

    --Obtengo la actividad principal del cliente.
    BEGIN
       SELECT a.cod_rub_primario
         INTO v_cod_act_primaria
         FROM ba_personas a
        WHERE a.cod_persona = g_cod_persona;
    EXCEPTION
       WHEN OTHERS THEN
          pr_err_mensajes('Actividad Principal no definida en (BA_PERSONAS). ' || SQLERRM);
    END;
    --Borro la verificación anterior de la persona cada vez que se ejecuta desde el epprocor
     lp_eli_tmp_tablas(g_cod_persona);
    -- Verifico los datos mandatorios para Personas Juridicas.
    IF v_tipo = 'J' THEN
       BEGIN
          SELECT bp.naturaleza, bp.fec_apertura, bp.can_empleados, bp.can_sucursales
            INTO v_naturaleza, v_fec_constitucion, v_can_empleados, v_can_sucursales
            FROM ba_per_juridicas bp
           WHERE bp.cod_persona = g_cod_persona;
       EXCEPTION
          WHEN OTHERS THEN
             v_naturaleza := NULL;
             v_fec_constitucion := NULL;
             v_can_empleados := NULL;
             v_can_sucursales := NULL;
       END;
       --
       IF v_naturaleza IS NULL THEN
          pr_ins_err_tablas('BA_PER_JURIDICA',
                            'NATURALEZA',
                            'Debe ingresar el Tipo de Sociedad de la Persona (Opción:Carpeta de la Persona/Pestaña:Personales).',
                            v_ins_registro);
       END IF;
       IF v_fec_constitucion IS NULL THEN
          pr_ins_err_tablas('BA_PER_JURIDICA',
                            'FEC_APERTURA',
                            'Debe ingresar la Fecha de Constitución de la Sociedad (Opción:Carpeta de la Persona/Pestaña:Personales).',
                            v_ins_registro);
       END IF;
       IF v_can_empleados IS NULL THEN
          pr_ins_err_tablas('BA_PER_JURIDICA',
                            'CAN_EMPLEADOS',
                            'Debe ingresar la Cantidad de Empleados de la Sociedad (Opción:Carpeta de la Persona/Pestaña:Personales).',
                            v_ins_registro);
       END IF;
       IF v_can_sucursales IS NULL THEN
          pr_ins_err_tablas('BA_PER_JURIDICA',
                            'CAN_SUCURSALES',
                           'Debe ingresar la Cantidad de Sucursales de la Sociedad (Opción:Carpeta de la Persona/Pestaña:Personales).',
                            v_ins_registro);
       END IF;
    END IF;
    -- Obtengo los campos mandatorios de acuerdo a la actividad del cliente.
    BEGIN
       SELECT a.cod_tip_actividad, a.plz_vigencia, a.mandatorio
         INTO v_cod_tip_actividad, v_plz_vigencia, v_mandatorio
         FROM ge_cam_obl_segmentacion a
        WHERE a.cod_rub_primario = v_cod_act_primaria;

       -- Verifico que los datos esten cargados en la tabla cr_per_dat_segmentacion.
       BEGIN
          SELECT cp.ano_facturacion, cp.mes_facturacion, cp.estado, cp.mes_rating, cp.ano_rating, cp.mto_facturacion, cp.mes_hatos, cp.ano_hatos, cp.can_hatos
            INTO v_anho, v_mes, v_estado, v_mes_rating, v_ano_rating, v_mto_facturacion, v_mes_hatos, v_ano_hatos, v_can_hatos
            FROM cr_per_dat_segmentacion cp
           WHERE cp.cod_persona = g_cod_persona
             AND cp.cod_rub_primario = v_cod_act_primaria
             AND to_date(cp.ano_facturacion||cp.mes_facturacion,'yyyymm') =
                 (SELECT MAX(to_date(cp1.ano_facturacion||cp1.mes_facturacion,'yyyymm')) FROM cr_per_dat_segmentacion cp1 WHERE cp1.cod_persona = cp.cod_persona AND cp1.cod_rub_primario = cp.cod_rub_primario);

          -- Asigno valores a los campos nulos.
          IF v_anho IS NULL THEN
             v_anho := '1900';
          END IF;
          --
          IF v_mes IS NULL THEN
             v_mes := '01';
          END IF;
          --
          IF v_estado IS NULL THEN
             v_estado := 'M';
          END IF;
          --
          IF v_mes_rating IS NULL THEN
             v_mes_rating := '01';
          END IF;
          --
          IF v_ano_rating IS NULL THEN
             v_ano_rating := '1900';
          END IF;
          --
          IF v_mto_facturacion IS NULL THEN
             v_mto_facturacion := 0;
          END IF;
          --
          IF v_mes_hatos IS NULL THEN
             v_mes_hatos := '01';
          END IF;
          --
          IF v_ano_hatos IS NULL THEN
             v_ano_hatos := '1900';
          END IF;
          --
          IF v_can_hatos IS NULL THEN
             v_can_hatos := 0;
          END IF;

          -- Verifico el estado del registro.
          IF v_estado = 'V' THEN
             -- Plazo de Vigencia.
             SELECT add_months(to_date(v_mes||'/'||v_anho,'mm/yyyy'),v_plz_vig_facturacion +1)
               INTO v_fec_plz_vigencia
               FROM dual;

             -- Verifico el plazo de vigencia de la facturación.
             SELECT COUNT(1)
               INTO v_control
               FROM dual
              WHERE v_fec_actual >= v_fec_plz_vigencia;

             IF v_control > 0 THEN
                pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                                  SUBSTR(fue_obt_sig_refcodes('COD_TIP_ACT_SEGMENTACION',v_cod_tip_actividad),1,30),
                                  'El plazo de vigente del Importe de Facturación declarado por la Persona se encuentra vencida (Opción:Carpeta de la Persona/Pestaña:Facturación).',
                                  v_ins_registro);
             END IF;
             -- Verifico el plazo de vigencia del rating.
             IF NVL(v_mto_facturacion,0) > NVL(v_mto_rating,0) THEN -- Comercial.
                -- Plazo de Vigencia Rating.
                SELECT add_months(to_date(v_mes_rating||'/'||v_ano_rating,'mm/yyyy'),v_plz_vig_rating +1)
                  INTO v_fec_plz_rating
                  FROM dual;

                -- Verifico el plazo de vigencia.
                SELECT COUNT(1)
                  INTO v_control
                  FROM dual
                 WHERE v_fec_actual >= v_fec_plz_rating;

                IF v_control > 0 THEN
                   pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                                     SUBSTR(fue_obt_sig_refcodes('COD_TIP_ACT_SEGMENTACION',v_cod_tip_actividad),1,30),
                                     'El plazo de vigencia del Rating se encuentra vencida (Opción:Carpeta de la Persona/Pestaña:Facturación)',
                                     v_ins_registro);
                END IF;
             END IF;
             -- Verifico los datos correspondientes a la actividad de ganadería.
             IF v_mandatorio = 'S' THEN
             IF v_cod_tip_actividad = 2 THEN -- Ganadera.
                -- Plazo de Vigencia Hatos.
                SELECT add_months(to_date(v_mes_hatos||'/'||v_ano_hatos,'mm/yyyy'),v_plz_vigencia +1)
                  INTO v_fec_plz_hatos
                  FROM dual;

                -- Verifico el plazo de vigencia.
                SELECT COUNT(1)
                  INTO v_control
                  FROM dual
                 WHERE v_fec_actual >= v_fec_plz_hatos;

                IF v_control > 0 THEN
                   pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                                     SUBSTR(fue_obt_sig_refcodes('COD_TIP_ACT_SEGMENTACION',v_cod_tip_actividad),1,30),
                                     'El plazo de vigencia de la cantidad de Hatos declarada se encuentra vencida (Opción:Carpeta de la Persona/Pestaña:Facturación).',
                                     v_ins_registro);
                END IF;
                --
                IF v_can_hatos <= 0 THEN
                   pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                                     SUBSTR(fue_obt_sig_refcodes('COD_TIP_ACT_SEGMENTACION',v_cod_tip_actividad),1,30),
                                     'La cantidad de Hatos registrada en la carpeta de la Persona no puede ser menor a Cero (Opción:Carpeta de la Persona/Pestaña:Facturación).',
                                     v_ins_registro);
                END IF;
             END IF;
             -- Verifico los datos correspondientes a la actividad de agricola.
             IF v_cod_tip_actividad = 3 THEN -- Agricola.
                FOR reg IN (SELECT cp.* FROM cr_per_tip_hectareas cp WHERE cp.cod_persona = p_cod_persona) LOOP
                   v_tip_hectarea := NULL;
                   -- Plazo de Vigencia.
                   SELECT add_months(to_date(reg.mes||'/'||reg.anho,'mm/yyyy'),v_plz_vigencia +1)
                     INTO v_fec_plz_hectareas
                     FROM dual;

                   -- Verifico el plazo de vigencia de la facturación, hatos, hectarias.
                   SELECT COUNT(1)
                     INTO v_control
                     FROM dual
                    WHERE v_fec_actual >= v_fec_plz_hectareas;

                   IF v_control > 0 THEN
                      v_tip_hectarea := SUBSTR(trim(fue_obt_sig_refcodes('COD_TIP_HEC_CULTIVADAS',reg.tip_hec_cultivadas)),1,60)    ;
                      pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                                        SUBSTR(fue_obt_sig_refcodes('COD_TIP_ACT_SEGMENTACION',v_cod_tip_actividad),1,30),
                                        'El plazo de vigencia para la cantidad de Hectáreas declarada para el Tipo de Hectárea: '||v_tip_hectarea||' se encuentra vencida (Opción:Carpeta de la Persona/Pestaña:Facturación).',
                                        v_ins_registro);
                   END IF;
                END LOOP;
                -- Verifico si existen datos cargados de la actividad agricola.
                SELECT COUNT(1)
                  INTO v_control
                  FROM cr_per_tip_hectareas cp
                 WHERE cp.cod_persona = p_cod_persona;
                --
                IF v_control = 0 THEN
                      pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                                        'AGRICOLA',
                                        'No existe registro de la cantidad de Hectáreas declaradas en la carpeta de la Persona (Opción:Carpeta de la Persona/Pestaña:Facturación).',
                                        v_ins_registro);
                END IF;
             END IF;
             END IF;
             -- Verifico si se generaron erroresde validación.
             SELECT COUNT(1)
               INTO v_control
               FROM ge_sol_ver_personas_det_tmp a
              WHERE a.cod_persona = p_cod_persona;
             --
             IF v_control > 0 THEN
                RAISE error;
             END IF;
          ELSE
             pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                               SUBSTR(fue_obt_sig_refcodes('COD_TIP_ACT_SEGMENTACION',v_cod_tip_actividad),1,30),
                               'Los Datos de Facturación registrados en la carpeta de la Persona no fueron verificados (Opción:Carpeta de la Persona/Pestaña:Facturación).',
                               v_ins_registro);
             RAISE error;
          END IF;

       EXCEPTION
          WHEN salir THEN
             RETURN TRUE;
          WHEN error THEN
             RETURN FALSE;
          WHEN OTHERS THEN
             pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                               'FACTURACION',
                               'No existen Datos de Facturación registrados en la carpeta de la Persona (Opción:Carpeta de la Persona/Pestaña:Facturación).',
                               v_ins_registro);
             --
             IF v_cod_tip_actividad = 2 THEN -- Ganadera.
                pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                                  SUBSTR(fue_obt_sig_refcodes('COD_TIP_ACT_SEGMENTACION',v_cod_tip_actividad),1,30),
                                  'Debe ingresar la cantidad de Hatos en la carpeta de la Persona (Opción:Carpeta de la Persona/Pestaña:Facturación).',
                                  v_ins_registro);
             END IF;
             --
             IF v_cod_tip_actividad = 3 THEN -- Agricola.
                pr_ins_err_tablas('CR_PER_DAT_SEGMENTACION',
                                  SUBSTR(fue_obt_sig_refcodes('COD_TIP_ACT_SEGMENTACION',v_cod_tip_actividad),1,30),
                                  'Debe ingresar la cantidad de Hectáreas en la carpeta de la Persona (Opción:Carpeta de la Persona/Pestaña:Facturación).',
                                   v_ins_registro);
             END IF;
             --
             RETURN FALSE;
       END;
       -- Termino el proceso correctamente.
       RETURN TRUE;
    EXCEPTION
       WHEN salir THEN
          RETURN TRUE;
       WHEN error THEN
          RETURN FALSE;
       WHEN OTHERS THEN
          NULL;
          --raise_application_error(-20000, SQLERRM);
          RETURN TRUE;
    END;
EXCEPTION
   WHEN salir THEN
      RETURN TRUE;
   WHEN error THEN
      RETURN FALSE;
END;
FUNCTION fu_obt_pro_mto_nomina(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                 p_fec_calculo IN ge_calendarios.fec_actual%type default null)
    RETURN NUMBER IS
    v_monto                      cc_movimientos_his.monto%TYPE := NULL;
    v_fec_inicial                ge_calendarios.fec_actual%type;
    v_fec_final                  ge_calendarios.fec_actual%type;
    v_mes_promedio               number := nvl(fug_obt_pardinamico('SCO_MES_CAL_PROMEDIO'),1); --Meses a considerar para periodo a calcular
    v_mto_promedio               ge_pag_sueldos.monto%TYPE := NULL;
    v_mes_anterior               number;
    v_mes                        number;
    v_can_mes_promedio           number := 0; ---Cantidad mes para calculo de promedio


    Cursor c_dat_creditos ( p_fec_inicial    ge_calendarios.fec_actual%type,
                            p_fec_final      ge_calendarios.fec_actual%type)is
     select to_char(g.fec_proceso, 'MMYYYY') mes, sum(pag_gen.FU_CON_MON_A_MONEDA(g.cod_moneda, 'GS', g.monto)) monto
       from ge_pag_sue_lotes l, ge_pag_sueldos g, ge_cta_clientes c
      where l.cod_ente(+) = g.cod_ente
        and l.fec_proceso(+) = g.fec_proceso
        and l.nro_secuencia(+) = g.nro_secuencia
        and g.nro_cuenta = c.nro_cuenta
        and c.relacion = 'P'
        and g.procesado = 'S'
        and l.tip_pago(+) = 'S'
        and g.tipo = 'C'
        and c.cod_persona = p_cod_persona
        and g.fec_proceso between p_fec_inicial and p_fec_final
      group by g.fec_proceso
      order by to_char(g.fec_proceso, 'MMYYYY');
  BEGIN
    --Asigno codigo de persona local a la variable global
    g_cod_persona := p_cod_persona;

    v_fec_inicial := nvl(p_fec_calculo, pag_cal.fu_obt_fec_actual(1));
    v_fec_inicial := to_date('01'||'/'||to_char(add_months(v_fec_inicial, - v_mes_promedio), 'MM')||'/'||to_char(add_months(v_fec_inicial, - v_mes_promedio), 'YYYY'),'dd/mm/yyyy');
    v_fec_final   := nvl(p_fec_calculo, pag_cal.fu_obt_fec_actual(1));
    v_fec_final   := last_day(to_date('01'||'/'||to_char(add_months(v_fec_final, - 1), 'MM')||'/'||to_char(add_months(v_fec_final, - 1), 'YYYY'),'dd/mm/yyyy'));

     ---Sumo los creditos por salario del cliente correspondiente al últimos meses (la cantidad esta parametrizada)
     for c_cre in c_dat_creditos(v_fec_inicial, v_fec_final) loop
         v_mes   :=  c_cre.mes;
         v_monto := nvl(v_monto ,0) + c_cre.monto;

         if v_mes  != nvl(v_mes_anterior, v_mes) then
            v_can_mes_promedio := v_can_mes_promedio + 1;
         end if;
         v_mes_anterior := v_mes;
     end loop;

     --Asignar 1 como valor minimo para el calulo de promedio(divisor del credito)
     if v_can_mes_promedio = 0 then
        v_can_mes_promedio := 1;
     else
        v_can_mes_promedio := v_can_mes_promedio + 1;
     end if;

      v_mto_promedio := round(nvl(v_monto,0) / v_can_mes_promedio,0);

     return nvl(v_mto_promedio,0);
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
       return nvl(v_mto_promedio,0);
     WHEN OTHERS THEN
       pr_err_mensajes('Error en (par_per.fu_obt_pro_mto_nomina). ' || SQLERRM);
  END fu_obt_pro_mto_nomina;
  --
  FUNCTION fu_obt_ingresos(p_cod_persona IN VARCHAR2,
                           p_tip_ingreso IN VARCHAR2,
                           p_nro_secuencia in NUMBER DEFAULT NULL) RETURN NUMBER IS

    v_ingreso       cr_inf_laborales.mto_ingreso%TYPE := 0;
    v_plazo         NUMBER(3);
    v_fec_actual    ge_calendarios.fec_actual%TYPE := fue_obt_fec_calendar(1);
    v_meses         NUMBER(3);
    v_nro_solicitud pr_solicitudes.nro_solicitud%TYPE;
    v_cod_modulo    pr_solicitudes.cod_sub_modalidad%TYPE;
    v_cod_modalidad pr_solicitudes.cod_sub_modalidad%TYPE;
    v_cod_sub_modal pr_solicitudes.cod_sub_modalidad%TYPE;
    --v_nomina        VARCHAR2(1);
    --v_excepcion     VARCHAR2(1);
    v_parametro     VARCHAR2(400);

    CURSOR c_ingresos IS
      SELECT a.cod_persona,a.fec_ingreso,a.mto_ingreso,a.tip_ingreso,b.cod_concepto,b.importe,a.nomina,a.cod_moneda
        FROM cr_inf_laborales a, cr_per_ing_egresos b
       WHERE a.cod_persona(+) = b.cod_persona
         AND b.cod_persona = p_cod_persona
         AND b.cod_concepto = p_tip_ingreso
         AND b.ing_egreso = 'I'
         AND a.tip_ingreso(+) = b.cod_concepto
         AND (p_nro_secuencia is null or a.nro_secuencia = p_nro_secuencia)
         AND a.actual = 'S';
  BEGIN
    --quitar
    --par_per.g_nro_solicitud := '755422';
    v_nro_solicitud := par_per.g_nro_solicitud;
    --v_nomina        := fug_es_cli_nomina(p_cod_persona);
    /*Se la sub_modalidad para verificar si corresponde a una excepcion*/
    BEGIN
      SELECT a.cod_modulo,a.cod_modalidad,a.cod_sub_modalidad
        INTO v_cod_modulo,v_cod_modalidad,v_cod_sub_modal
        FROM pr_solicitudes a
       WHERE a.nro_solicitud = v_nro_solicitud;
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          SELECT a.cod_modulo,a.cod_modalidad,a.cod_sub_modalidad
            INTO v_cod_modulo,v_cod_modalidad,v_cod_sub_modal
            FROM ta_solicitudes a
           WHERE a.nro_solicitud = v_nro_solicitud;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_modulo    := 0;
            v_cod_modalidad := 0;
            v_cod_sub_modal := 0;
        END;
    END;
    --v_excepcion := NVL(fug_obt_pardinamico('SCO_SUB_MOD_EXCEPCIONES',v_cod_modulo,v_cod_modalidad,NULL,NULL,v_cod_sub_modal),'N');
    v_parametro := NVL(fug_obt_pardinamico('SCO_SUB_MOD_EXCEPCIONES',v_cod_modulo,v_cod_modalidad,NULL,NULL,v_cod_sub_modal),'PLA_GENERAL');

    FOR i IN c_ingresos LOOP
      v_plazo := NVL(fue_tab_dat_adicional('CR_CON_ING_EGR',v_parametro,i.cod_concepto),
                     fue_tab_dat_adicional('CR_CON_ING_EGR','PLA_GENERAL',i.cod_concepto));
      /*IF v_excepcion = 'S' THEN
        --v_plazo := 0;
        v_plazo := NVL(fue_tab_dat_adicional('CR_CON_ING_EGR','PLA_EXCEPCION',i.cod_concepto),
                       fue_tab_dat_adicional('CR_CON_ING_EGR','PLA_SCORING',i.cod_concepto));
      ELSE
        -- plazo establecido en meses para tener encuenta el ingreso por tipo
        v_plazo := fue_tab_dat_adicional('CR_CON_ING_EGR','PLA_SCORING',i.cod_concepto);
      END IF;*/

      -- meses cumplidos
      v_meses := round((v_fec_actual-NVL(i.fec_ingreso,v_fec_actual))/30);

      IF v_meses >= v_plazo THEN
        -- mayor al plazo se toma todo los ingresos
        v_ingreso := v_ingreso + i.mto_ingreso;
        v_ingreso := pag_gen.FU_CON_MON_A_MONEDA(i.cod_moneda, 'GS', v_ingreso);
      ELSIF i.cod_concepto IN (1,3,8) OR (p_nro_secuencia IS NOT NULL AND nvl(i.nomina, 'N') = 'S') THEN
        v_ingreso := v_ingreso + i.importe;
        v_ingreso := pag_gen.FU_CON_MON_A_MONEDA(i.cod_moneda, 'GS', v_ingreso);
      END IF;

    END LOOP;
    RETURN v_ingreso;
  END fu_obt_ingresos;
  --
  FUNCTION fu_cal_cuota(p_nro_solicitud IN NUMBER) RETURN NUMBER IS
    v_redondeo         NUMBER(2) := 0;
    v_mon_local        VARCHAR2(3) := pag_gen.FU_OBT_MON_LOCAL;
    --v_max_cuota        pr_sol_cuotas.mto_capital%TYPE;
    v_tot_cuota        pr_sol_cuotas.mto_capital%TYPE;
    v_nro_cuota        pr_sol_cuotas.nro_cuota%TYPE;
    v_mto_cuota        pr_sol_cuotas.mto_capital%TYPE;
    v_cuo_mto_capital  pr_sol_cuotas.mto_capital%TYPE;
    v_cuo_mto_interes  pr_sol_cuotas.val_interes%TYPE;
    v_mto_car_seg_vida pr_sol_cuotas.mto_capital%TYPE;
    v_mto_seg_incendio pr_sol_cuotas.mto_capital%TYPE;
    v_obt_tasa         VARCHAR2(1) := 'N';
    v_tas_interes      ge_tas_fechas.val_tasa%TYPE;
    v_mto_iva_interes  pr_sol_cuotas.mto_capital%TYPE;
    v_tot_cargos       pr_sol_cuotas.mto_capital%TYPE;
    v_nro_garantia     pr_sol_garantias.nro_garantia%TYPE;
    v_cod_garantia     pr_sol_garantias.cod_garantia%TYPE;
    --
    ww_nomtra         VARCHAR2(200);
    ww_codtas          NUMBER;
    ww_aplicar        VARCHAR2(2);
    ww_tpvlpor        VARCHAR2(2);
    ww_tpdetas        VARCHAR2(2);
    ww_obligat        VARCHAR2(2);
    ww_afecta         VARCHAR2(2);

    rg_solicitudes pr_solicitudes%ROWTYPE;

    CURSOR cargos(p_exo_impuesto VARCHAR2, p_cod_modalidad NUMBER) IS
      SELECT decode(cod_transaccion,709,1,710,2,3) orden,  -- solo para ordenamiento
             cod_transaccion, cod_ent_seguro
        FROM ge_sol_cargos
       WHERE cod_modulo = 6
         AND cod_modalidad = p_cod_modalidad
         AND ((NVL(p_exo_impuesto,'N') = 'N') or
              (NVL(p_exo_impuesto,'N') = 'S' and cod_transaccion NOT IN (709,710)))
         AND cod_canal IS NULL
         AND cod_campana IS NULL
         AND (cod_tip_canal IS NULL)
       ORDER BY 1;
    -- obtener el nro de cuota para calcular max cargos cuotizados
    FUNCTION fp_obt_max_cuota(p_nro_solicitud NUMBER) RETURN NUMBER IS
      v_cuota pr_sol_cuotas.nro_cuota%TYPE;
    BEGIN
      SELECT MIN(a.nro_cuota)
        INTO v_cuota
        FROM pr_sol_cuotas a, pr_solicitudes b
       WHERE a.nro_solicitud = p_nro_solicitud
         AND a.nro_solicitud = b.nro_solicitud
         AND (nvl(a.mto_capital, 0) - decode(b.tipo, 'D', nvl(a.val_int_adelantado, 0), 0) + a.val_interes) =
             (SELECT MAX(nvl(c.mto_capital, 0) - decode(a.tipo, 'D', nvl(c.val_int_adelantado, 0), 0) + c.val_interes) max_cuota
                FROM pr_sol_cuotas c, pr_solicitudes a
               WHERE c.nro_solicitud = a.nro_solicitud
                 AND a.nro_solicitud = p_nro_solicitud
                 AND c.nro_cuota > 0);
      RETURN (v_cuota);
    END fp_obt_max_cuota;
    -- obtener tipo de tasa
    PROCEDURE pr_obt_tip_tasa(p_cod_modulo IN NUMBER,
                              p_cod_modalidad IN NUMBER,
                              ww_cdtrans IN NUMBER,
                              ww_nmtrans IN OUT VARCHAR2,
                              ww_cddetas IN OUT NUMBER,
                              ww_aplicar IN OUT VARCHAR2,
                              ww_tpvlpor IN OUT VARCHAR2,
                              ww_tpdetas IN OUT VARCHAR2,
                              ww_obligatorio IN OUT VARCHAR2,
                              ww_afecta IN OUT VARCHAR2) IS
    BEGIN
      -- 1. Busco la tasa asociada a la transaccion ingresada --
      SELECT initcap(tr.descripcion),tr.cod_tasa,ta.aplicar,ta.tip_valor,ta.tipo, dt.obligatorio, tr.afecta
        INTO ww_nmtrans,ww_cddetas,ww_aplicar,ww_tpvlpor,ww_tpdetas, ww_obligatorio, ww_afecta
        FROM ge_transacciones_det dt, ge_transacciones tr, ge_tasas ta
       WHERE tr.cod_modulo = p_cod_modulo
         AND tr.cod_modalidad = p_cod_modalidad
         AND tr.cod_transaccion = ww_cdtrans
         AND tr.tipo = 'D'
         AND tr.cod_tasa IS NOT NULL
         AND tr.cod_tasa = ta.cod_tasa
         AND dt.cod_modulo = p_cod_modulo
         AND dt.cod_modalidad = p_cod_modalidad
         AND dt.cod_transaccion = 358 /* transaccion de desembolso de prestamos */
         AND dt.cod_mod_hijo = tr.cod_modulo
         AND dt.cod_mad_hijo = tr.cod_modalidad
         AND dt.cod_tra_hijo = tr.cod_transaccion;
    EXCEPTION
      WHEN no_data_found THEN
         pr_err_mensajes('ERROR: Cargo no definido para Préstamos.');
      WHEN OTHERS THEN
         pr_err_mensajes('Error en (par_per.fu_cal_cuota). ' ||SQLERRM);
    END pr_obt_tip_tasa;

  BEGIN
    -- obtener datos de la solicitud
    BEGIN
      SELECT a.cod_modulo, a.cod_modalidad,a.cod_moneda,a.cod_oficina, a.fec_inicio,
             a.fec_vencimiento, a.tipo, a.tot_prestamo, a.exo_impuesto, a.cod_sub_modalidad,
             a.iva_desglose
        INTO rg_solicitudes.cod_modulo, rg_solicitudes.cod_modalidad,rg_solicitudes.cod_moneda,rg_solicitudes.cod_oficina, rg_solicitudes.fec_inicio,
             rg_solicitudes.fec_vencimiento, rg_solicitudes.tipo, rg_solicitudes.tot_prestamo, rg_solicitudes.exo_impuesto, rg_solicitudes.cod_sub_modalidad,
             rg_solicitudes.iva_desglose
        FROM pr_solicitudes a
       WHERE a.nro_solicitud = p_nro_solicitud;
    EXCEPTION
      WHEN no_data_found THEN
        pr_err_mensajes('Error en (par_per.fu_cal_cuota). ' || SQLERRM);
    END;
    v_nro_cuota := fp_obt_max_cuota(p_nro_solicitud);

    IF rg_solicitudes.cod_moneda <> v_mon_local THEN
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_solicitudes.cod_modalidad, rg_solicitudes.cod_moneda, rg_solicitudes.cod_oficina, rg_solicitudes.cod_sub_modalidad);
    END IF;

    -- obtener datos de la max cuota
    BEGIN
      SELECT MAX(nvl(c.mto_capital, 0) - decode(a.tipo, 'D', nvl(c.val_int_adelantado, 0), 0) + c.val_interes) max_cuota
        , c.mto_capital, c.val_interes
        INTO v_mto_cuota, v_cuo_mto_capital, v_cuo_mto_interes
        FROM pr_sol_cuotas c, pr_solicitudes a
       WHERE c.nro_solicitud = a.nro_solicitud
         AND a.nro_solicitud = p_nro_solicitud
         AND c.nro_cuota = v_nro_cuota
       GROUP BY c.mto_capital,c.val_interes;
    END;

    -- para los nuevos calculos ya guarda el cargo cuotizado
    IF fug_obt_pardinamico('PRE_NUE_CAL_SEGUROS',rg_solicitudes.cod_modulo,rg_solicitudes.cod_modalidad, NULL, NULL) = 'S' THEN
      BEGIN
        SELECT t.monto mto_seguro
          INTO v_mto_car_seg_vida
          FROM pr_cta_gas_seguros t
         WHERE t.nro_solicitud = p_nro_solicitud
           AND t.nro_cuota = v_nro_cuota;
      EXCEPTION
        WHEN no_data_found THEN
          pr_err_mensajes('Error al obtener cagos Seguro de Vida (par_per.fu_cal_cuota). ' || SQLERRM);
      END;
    ELSE -- para los que no estan se calcula como en el epprocor calcular_cuota_cargo
      --rg_solicitudes.tot_prestamo;

      FOR ca IN cargos(rg_solicitudes.exo_impuesto,rg_solicitudes.cod_modalidad) LOOP
        pr_obt_tip_tasa(rg_solicitudes.cod_modulo,rg_solicitudes.cod_modalidad,ca.cod_transaccion,ww_nomtra,
                        ww_codtas,ww_aplicar,ww_tpvlpor,ww_tpdetas,ww_obligat,ww_afecta);
        IF ca.cod_transaccion IN ('1521') AND ca.cod_ent_seguro IS NOT NULL THEN
          v_mto_car_seg_vida := pap_pre.FU_OBT_CAL_MTO_SEG_VIDA(rg_solicitudes.cod_modalidad,
                                                                rg_solicitudes.cod_modulo,
                                                                rg_solicitudes.cod_moneda,
                                                                rg_solicitudes.cod_oficina,
                                                                rg_solicitudes.tot_prestamo, --ww_vlsalan
                                                                ca.cod_ent_seguro,
                                                                rg_solicitudes.fec_inicio,
                                                                rg_solicitudes.fec_vencimiento,
                                                                ww_tpdetas,
                                                                rg_solicitudes.tot_prestamo);
        END IF;
      END LOOP;
    END IF;

    FOR ca IN cargos(rg_solicitudes.exo_impuesto,rg_solicitudes.cod_modalidad) LOOP
      -- cargo IVA y seguro de incendio si corresponde
      IF rg_solicitudes.iva_desglose = 'S' THEN
        IF nvl(v_obt_tasa, 'N') = 'N' THEN
          v_tas_interes := fug_obt_val_tasa(rg_solicitudes.cod_modulo,
                                            rg_solicitudes.cod_modalidad,
                                            null, -- cod_oficina
                                            null, -- nro_cuenta
                                            rg_solicitudes.cod_moneda,
                                            null, -- mto_transaccion
                                            null, -- tas_personalizada
                                            null, -- cod_tasa
                                            ca.cod_transaccion,
                                            rg_solicitudes.fec_inicio);

          v_obt_tasa := 'S';
        END IF;
        v_mto_iva_interes := round(v_cuo_mto_interes * v_tas_interes/ 100, v_redondeo);
      ELSE
        v_mto_iva_interes := 0;
      END IF;
      BEGIN
        -- buscamos solo hipotecarios
        SELECT a.nro_garantia, a.cod_garantia
          INTO v_nro_garantia, v_cod_garantia
          FROM pr_sol_garantias a
         WHERE a.nro_solicitud = p_nro_solicitud
           AND a.cod_garantia IN (3, 13);
      EXCEPTION
        WHEN no_data_found THEN
          --pr_err_mensajes('Error al obtener garantia Hipotecaria (par_per.fu_cal_cuota). ' || SQLERRM);
          v_cod_garantia := 1;-- sola firma
      END;
      IF v_cod_garantia IN (3, 13) THEN  -- Res. 12
        IF v_nro_garantia IS NOT NULL THEN
          IF ca.cod_transaccion IN ('1520') THEN
            v_mto_seg_incendio := pap_pre.FU_OBT_CAL_MTO_SEG_INCENDIO(rg_solicitudes.cod_modalidad,
                                                                      rg_solicitudes.cod_modulo,
                                                                      rg_solicitudes.cod_oficina,
                                                                      v_nro_garantia ,
                                                                      0,
                                                                      ca.cod_ent_seguro,
                                                                      rg_solicitudes.cod_moneda,
                                                                      rg_solicitudes.fec_inicio);
          END IF;
        END IF;
      END IF;
    END LOOP;

    -- total de cargos
    v_tot_cargos := nvl(v_tot_cargos,0) + nvl(v_mto_car_seg_vida,0) + nvl(v_mto_iva_interes,0) + nvl(v_mto_seg_incendio,0);

    -- total cuota
    v_tot_cuota := v_mto_cuota + v_tot_cargos;

    RETURN v_tot_cuota;
  END fu_cal_cuota;
  
END;
/
