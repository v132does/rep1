CREATE OR REPLACE PACKAGE BODY IT.pap_com IS
   -- Obtiene Datos de la compra.
  Cursor Ctas Is
    Select a.Cod_Oficina,
           trim( decode(a.cod_tip_documento,1,regexp_substr(a.Nro_Documento, '\d+',1),a.Nro_Documento)) Nro_Documento,
           a.Cod_Tip_Documento,
           a.Cod_Pais,
           Trim(a.Nombre) Nombre,
           Trim(a.Apellido) Apellido,
           a.Tipo,
           a.Cod_Sex_Cliente,
            case when a.fec_nacimiento is null or
                      a.fec_nacimiento < (pae_cnf.fu_obt_fec_actual('1') - 36500) or
                      a.fec_nacimiento > pae_cnf.fu_obt_fec_actual('1') then
                      pae_cnf.fu_obt_fec_actual('1') - (add_months(pae_cnf.fu_obt_fec_actual('1'), a.antiguedad) - pae_cnf.fu_obt_fec_actual('1'))
                 else null end fec_nacimiento,
           a.Dir_Particular,
           a.Nro_Dir_Particular,
           a.Cod_Pais_Dir_Particular,
           a.Cod_Ciu_Dir_Particular,
           a.Cod_Bar_Dir_Particular,
           a.Obs_Dir_Particular,
           a.Dir_Laboral,
           a.Nro_Dir_Laboral,
           a.Cod_Pais_Dir_Laboral,
           a.Cod_Ciu_Dir_Laboral,
           a.Cod_Bar_Dir_Laboral,
           a.Obs_Dir_Laboral,
           a.Tip_Linea_Particular,
           a.Area_Tel_Particular,
           a.Tel_Particular,
           a.Tip_Linea_Laboral,
           a.Area_Tel_Laboral,
           a.Tel_Laboral,
           a.Lug_Trabajo,
           a.Mto_Ingreso,
           a.Antiguedad,
           a.Des_Puesto,
           a.Cod_Banca,
           a.Cod_Rub_Primario,
           a.Cod_Rub_Economico,
           a.Tip_Destino,
           a.Cod_Moneda,
           a.Sal_Prestamo,
           a.Can_Cuotas,
           a.Val_Tasa,
           a.Fec_Pri_Vencimiento,
           a.Mto_Cuota,
           a.Mto_Gto_Administrativo,
           a.Mto_Seguro,
           a.Descripcion,
           a.Nro_Operacion,
           a.Nro_Lote,
           a.Cod_Ente,
           a.Cod_Canal,
           a.Cod_Campana,
           a.Cod_Usu_Oficial,
           a.Fec_Ini_Operacion,
           a.Nom_Codeudor,
           a.Ape_Codeudor,
           a.Nro_Doc_Codeudor,
           a.Cod_Tip_Doc_Codeudor,
           a.Cod_Sex_Codeudor,
           a.Nom_Conyuge,
           a.Ape_Conyuge,
           a.Nro_Doc_Conyuge,
           a.Cod_Tip_Doc_Conyuge,
           a.Cod_Sex_Conyuge,
           a.Nom_Cony_Codeudor,
           a.Ape_Cony_Codeudor,
           a.Nro_Doc_Cony_Codeudor,
           a.Cod_Tip_Doc_Cony_Codeudor,
           a.Cod_Sex_Cony_Codeudor,
           a.Judicializado,
           a.Fec_Juicio,
           a.Inhibido,
           a.Fec_Inhibicion,
           a.Ind_Recurso,
           tip_prestamo, -- COMERCIAL o CONSUMO
           sec_publico,   -- Valor S o N
           b.cod_persona
      From Pr_Com_Cartera a, ba_personas b
     Where Procesado = 'N'
     And a.nro_documento = b.nro_documento(+);


   CURSOR cuo_ctas
   (
      p_cod_entidad   IN pr_com_cartera.cod_ente%TYPE,
      p_nro_operacion IN pr_com_cartera.nro_operacion%TYPE
   ) IS
      SELECT c.nro_operacion, c.nro_cuota, c.fec_vencimiento, c.mto_cuota, c.nro_cheque,
             c.cod_banco, c.cta_libradora, c.fec_emision, c.mto_cheque, c.nom_librador,
             c.ape_librador, c.nro_doc_librador, c.cod_tip_doc_librador, c.cod_sex_librador,
             nvl(c.sal_capital, 0) sal_capital, nvl(c.sal_interes, 0) sal_interes
        FROM pr_cuo_com_cartera c
       WHERE c.cod_ente = p_cod_entidad
         AND c.nro_operacion = p_nro_operacion
       ORDER BY c.nro_operacion, c.nro_cuota;

   v_cod_persona     ba_personas.cod_persona%TYPE := NULL;
   v_observacion     ba_direcciones.observacion%TYPE := NULL;
   v_tip_ingreso     cr_inf_laborales.tip_ingreso%TYPE := '1'; -- 1-SUELDO
   v_cod_oficial     ge_clientes.cod_usu_oficial%TYPE;
   v_nro_operacion   pr_com_cartera.nro_operacion%TYPE := NULL;
   v_com_error       pr_log_com_cartera.comentario%TYPE := NULL;
   v_cod_oficina     pr_solicitudes.cod_oficina%TYPE;
   v_cod_modulo      pr_solicitudes.cod_modulo%TYPE := 6;
   v_cod_modalidad   pr_solicitudes.cod_modalidad%TYPE := 613; ----Modalidad Compra de cartera
   v_cod_moneda      pr_solicitudes.cod_moneda%TYPE;
   v_cod_entidad     pr_com_cartera.cod_ente%TYPE := NULL;
   v_cod_sec_credito pr_solicitudes.cod_sec_credito%TYPE := NULL;
   v_cod_ente        ge_entes.cod_ente%TYPE;
   v_cod_per_cony    ba_personas.cod_persona%TYPE := NULL;
   v_cod_per_codeu   ba_personas.cod_persona%TYPE := NULL;
   v_cod_per_cony_codeu ba_personas.cod_persona%TYPE := NULL;
   v_cod_per_librador   ba_personas.cod_persona%TYPE := NULL;
   v_cod_pais           ba_personas.cod_pais%TYPE;
   v_cod_rub_economico  ba_personas.cod_rub_primario%TYPE;
   v_con_error       VARCHAR2(1) := 'N';
   v_usuario         VARCHAR2(20) := upper(USER);
   v_nro_registro    NUMBER(20) := NULL;
   v_fec_actual      DATE := pae_cnf.fu_obt_fec_actual('1');
   v_fec_inicio      DATE := pae_cnf.fu_obt_fec_actual('1');
   v_fec_ini_operacion DATE;
   v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;

   -- Procedimiento que Inserta las Direcciones.
   PROCEDURE pr_ins_dir_personas
   (
      p_dir_particular      IN ba_direcciones.direccion%TYPE,
      p_dir_laboral         IN ba_direcciones.direccion%TYPE,
      p_pais_dir_particular IN ba_direcciones.cod_pais%TYPE,
      p_pais_dir_laboral    IN ba_direcciones.cod_pais%TYPE,
      p_ciu_dir_part        IN ba_direcciones.cod_ciudad%TYPE,
      p_ciu_dir_lab         IN ba_direcciones.cod_ciudad%TYPE,
      p_bar_dir_particular  IN ba_direcciones.cod_barrio%TYPE,
      p_bar_dir_laboral     IN ba_direcciones.cod_barrio%TYPE,
      p_nro_dir_particular  IN ba_direcciones.numero%TYPE,
      p_nro_dir_laboral     IN ba_direcciones.numero%TYPE,
      p_obs_dir_particular  IN ba_direcciones.observacion%TYPE,
      p_obs_dir_laboral     IN ba_direcciones.observacion%TYPE,
      p_cod_persona         IN ba_personas.cod_persona%TYPE default null,
      p_cod_ente            IN ge_entes.cod_ente%TYPE default null,
      p_proceso             IN varchar2 default null
   ) IS
      v_proceso varchar2(20) := null;
   BEGIN
      IF p_proceso is not null THEN
         v_proceso := p_proceso;
      END IF;


      DECLARE
         v_cod_direccion ba_direcciones.cod_direccion%TYPE := 0;
         v_principal     ba_direcciones.principal%TYPE := 'N';
      BEGIN
         --si no tiene direccion principal.
         IF p_dir_particular IS NOT NULL THEN

            BEGIN

               SELECT cod_direccion
                 INTO v_cod_direccion
                 FROM ba_direcciones d
                WHERE d.cod_persona = nvl(v_cod_persona, p_cod_persona)
                  AND d.cod_direccion = (SELECT MAX(cod_direccion)
                                           FROM ba_direcciones dd
                                          WHERE dd.cod_persona = d.cod_persona);

               v_cod_direccion := v_cod_direccion + 1;

            EXCEPTION
               WHEN no_data_found THEN
                  v_cod_direccion := 1;
                  v_principal     := 'S';
            END;

            INSERT INTO ba_direcciones
               (cod_persona, cod_direccion, direccion, tipo, principal, observacion, cod_pais,
                cod_ciudad, cod_barrio, numero)
            VALUES
               (nvl(v_cod_persona, p_cod_persona), v_cod_direccion, p_dir_particular, 'P', v_principal,
                p_obs_dir_particular, p_pais_dir_particular, p_ciu_dir_part, p_bar_dir_particular,
                p_nro_dir_particular);

         ELSE
            v_con_error := 'S';
            pr_ins_log(0000, 'VERIFICAR LA DIRECCION, EL PROCESO CONTINUA',
                       v_com_error || ', PR_INS_DIR_PERSONAS', v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
         END IF;

         --direccion Laboral
         IF p_dir_laboral IS NOT NULL THEN
            v_principal := 'N';

            BEGIN

               SELECT cod_direccion
                 INTO v_cod_direccion
                 FROM ba_direcciones d
                WHERE d.cod_persona = nvl(v_cod_persona, p_cod_persona)
                  AND d.cod_direccion = (SELECT MAX(cod_direccion)
                                           FROM ba_direcciones dd
                                          WHERE dd.cod_persona = d.cod_persona);

               v_cod_direccion := v_cod_direccion + 1;

            EXCEPTION
               WHEN no_data_found THEN
                  v_cod_direccion := 1;
                  v_principal     := 'S';
            END;

            INSERT INTO ba_direcciones
               (cod_persona, cod_direccion, direccion, tipo, principal, observacion, cod_pais,
                cod_ciudad, cod_barrio, numero)
            VALUES
               (nvl(v_cod_persona, p_cod_persona), v_cod_direccion, p_dir_laboral, 'L', v_principal, p_obs_dir_laboral,
                p_pais_dir_laboral, p_ciu_dir_lab, p_bar_dir_laboral, p_nro_dir_laboral);

         ELSE
            v_con_error := 'N';
            pr_ins_log(0000, 'SIN DIRECCION LANBORAL, EL PROCESO CONTINUA',
                       v_com_error || ', PR_INS_DIR_PERSONAS', v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
         END IF;

      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_DIR_PERSONAS',
                       v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
      END;

   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';
         pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_DIR_PERSONAS',
                    v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
   END;

   -- Procedimiento que Inserta los Telefonos.
   PROCEDURE pr_ins_tel_personas
   (
      p_tel_particular  IN ba_telefonos.telefono%TYPE,
      p_tel_laboral     IN ba_telefonos.telefono%TYPE,
      p_area_particular IN ba_telefonos.area%TYPE,
      p_area_laboral    IN ba_telefonos.area%TYPE,
      p_tip_linea_p     IN ba_telefonos.tip_linea%TYPE,
      p_tip_linea_l     IN ba_telefonos.tip_linea%TYPE,
      p_cod_persona     IN ba_personas.cod_persona%TYPE default null,
      p_cod_ente            IN ge_entes.cod_ente%TYPE default null,
      p_proceso             IN varchar2 default null
   ) IS
      v_proceso varchar2(20) := null;
      v_existe varchar2(1) default 'N';
   BEGIN
      IF p_proceso is not null THEN
         v_proceso := p_proceso;
      END IF;
      DECLARE
         v_cod_telefono ba_telefonos.cod_telefono%TYPE := 0;
         v_principal    VARCHAR2(1) := 'N';
      BEGIN

         IF p_tel_particular IS NOT NULL THEN

            BEGIN

               SELECT cod_telefono
                 INTO v_cod_telefono
                 FROM ba_telefonos d
                WHERE d.cod_persona = nvl(v_cod_persona, p_cod_persona)
                  AND d.cod_telefono = (SELECT MAX(cod_telefono)
                                          FROM ba_telefonos dd
                                         WHERE dd.cod_persona = d.cod_persona);

               v_cod_telefono := v_cod_telefono + 1;

            EXCEPTION
               WHEN no_data_found THEN
                  v_cod_telefono := 1;
                  v_principal    := 'S';
            END;

            -- Que no duplique el mismo telefono controlado por el UK
            v_existe := 'N';
            Begin
              select 'S'
               into v_existe
               from ba_telefonos a
               where a.telefono = substr(REPLACE(REPLACE(p_tel_particular, ' ', ''), '-', ''), 1, 10)
               and  a.cod_persona = nvl(v_cod_persona, p_cod_persona)
               and rownum = 1;
            exception
              when others then
                v_existe := 'N';
            end;

          if v_existe = 'N' then
            INSERT INTO ba_telefonos
               (cod_persona, cod_telefono, area, telefono, interno, observacion, tipo, tip_linea,
                principal)
            VALUES
               (nvl(v_cod_persona, p_cod_persona), v_cod_telefono, p_area_particular,
                substr(REPLACE(REPLACE(p_tel_particular, ' ', ''), '-', ''), 1, 10), NULL, NULL, 'P',
                p_tip_linea_p, v_principal);
          end if;
         ELSE
            v_con_error := 'S';
            pr_ins_log(0000, 'VERIFICAR EL TELEFONO, EL PROCESO CONTINUA',
                       v_com_error || ', PR_INS_TEL_PERSONAS', v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
         END IF;

         IF p_tel_laboral IS NOT NULL THEN
            v_principal := 'N';

            BEGIN

               SELECT cod_telefono
                 INTO v_cod_telefono
                 FROM ba_telefonos d
                WHERE d.cod_persona = nvl(v_cod_persona, p_cod_persona)
                  AND d.cod_telefono = (SELECT MAX(cod_telefono)
                                          FROM ba_telefonos dd
                                         WHERE dd.cod_persona = d.cod_persona);

               v_cod_telefono := v_cod_telefono + 1;

            EXCEPTION
               WHEN no_data_found THEN
                  v_cod_telefono := 1;
                  v_principal    := 'S';
            END;

            -- Que no duplique el mismo telefono controlado por el UK
            v_existe := 'N';
            Begin
              select 'S'
               into v_existe
               from ba_telefonos a
               where a.telefono = substr(REPLACE(REPLACE(p_tel_laboral, ' ', ''), '-', ''), 1, 10)
               and  a.cod_persona = nvl(v_cod_persona, p_cod_persona)
               and rownum = 1;
            exception
              when others then
                v_existe := 'N';
            end;

          if v_existe = 'N' then
            INSERT INTO ba_telefonos
               (cod_persona, cod_telefono, area, telefono, interno, observacion, tipo, tip_linea,
                principal)
            VALUES
               (nvl(v_cod_persona, p_cod_persona), v_cod_telefono, p_area_laboral,
                substr(REPLACE(REPLACE(p_tel_laboral, ' ', ''), '-', ''), 1, 10), NULL, NULL, 'L',
                p_tip_linea_l, v_principal);
           end if;

         ELSE
            v_con_error := 'N';
            pr_ins_log(0000, 'SIN TELEFONO LABORAL, EL PROCESO CONTINUA',
                       v_com_error || ', PR_INS_TEL_PERSONAS', v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
         END IF;

      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_TEL_PERSONAS',
                       v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
      END;

   END;

   -- Procedimiento que Inserta Informacion Laboral.
   PROCEDURE pr_ins_cr_inf_laboral
   (
      p_lug_trabajo IN cr_inf_laborales.lug_trabajo%TYPE,
      p_mto_ingreso IN cr_inf_laborales.mto_ingreso%TYPE,
      p_cargo       IN cr_inf_laborales.des_puesto%TYPE,
      p_antiguedad  IN NUMBER,
      p_cod_persona IN ba_personas.cod_persona%TYPE default null,
      p_cod_ente    IN ge_entes.cod_ente%TYPE default null,
      p_proceso     IN varchar2 default null
   ) IS
      v_proceso varchar2(20) := null;
      v_fec_ingreso DATE := NULL;

   BEGIN
      IF p_proceso is not null THEN
         v_proceso := p_proceso;
      END IF;
      DECLARE
         v_nro_secuencia cr_inf_laborales.nro_secuencia%TYPE := 0;
         v_dir_laboral   cr_inf_laborales.cod_direccion%TYPE;
         v_tel_laboral   cr_inf_laborales.cod_telefono%TYPE;
      BEGIN

         v_fec_ingreso := v_fec_inicio - (add_months(v_fec_inicio, p_antiguedad) - v_fec_inicio);

         BEGIN

            SELECT nro_secuencia, cod_direccion, cod_telefono
              INTO v_nro_secuencia, v_dir_laboral, v_tel_laboral
              FROM cr_inf_laborales d
             WHERE d.cod_persona = nvl(v_cod_persona, p_cod_persona)
               AND d.nro_secuencia = (SELECT MAX(nro_secuencia)
                                        FROM cr_inf_laborales dd
                                       WHERE dd.cod_persona = d.cod_persona);

            v_nro_secuencia := v_nro_secuencia + 1;

         EXCEPTION
            WHEN no_data_found THEN
               v_nro_secuencia := 1;
         END;
         IF v_dir_laboral is null THEN
            SELECT max(d.cod_direccion)
              INTO v_dir_laboral
              FROM ba_direcciones d
             WHERE d.cod_persona = nvl(v_cod_persona, p_cod_persona)
               AND d.tipo='L';
         END IF;
         IF v_tel_laboral is null THEN
            SELECT max(t.cod_telefono)
              INTO v_tel_laboral
              FROM ba_telefonos t
             WHERE t.cod_persona = nvl(v_cod_persona, p_cod_persona)
               AND t.tipo='L';
         END IF;
      begin
         INSERT INTO cr_inf_laborales
            (cod_persona, nro_secuencia, lug_trabajo, fec_ingreso, mto_ingreso, cod_moneda, actual,
             tip_cargo, tip_ingreso, tip_empleo, cod_ramo, cod_direccion, cod_telefono, des_puesto)
         VALUES
            (nvl(v_cod_persona, p_cod_persona), v_nro_secuencia, p_lug_trabajo, v_fec_ingreso, p_mto_ingreso, 'GS', 'S',
             'E', v_tip_ingreso, 'D', '7', v_dir_laboral, v_tel_laboral, p_cargo);
       exception
         when others then
           v_con_error := 'S';
                    pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ',PR_INS_CR_INF_LABORAL',
                       v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
       end;
      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';
            IF SQLCODE = '-2291' THEN
               pr_ins_log(SQLCODE,
                          'DIRECCION Y/O TELEFONO LABORAL NO ASIGNADO, INGRESAR DE FORMA MANUAL, EL PROCESO CONTINUA',
                          v_com_error || ', PR_INS_CR_INF_LABORAL', v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
            ELSE
               pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500),
                          v_com_error || ', PR_INS_CR_INF_LABORAL', v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
            END IF;
      END;
   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';
         IF SQLCODE = '-2291' THEN
            pr_ins_log(SQLCODE,
                       'DIRECCION Y/O TELEFONO LABORAL NO ASIGNADO, INGRESAR DE FORMA MANUAL, EL PROCESO CONTINUA',
                       v_com_error || ', PR_INS_CR_INF_LABORAL', v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
         ELSE
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_CR_INF_LABORAL',
                       v_fec_actual, v_proceso, nvl(p_cod_ente, v_cod_ente));
         END IF;
   END;

   -- Procedimiento que Inserta el Cliente.
   PROCEDURE pr_ins_ge_cliente
   (
      p_cod_persona IN ba_personas.cod_persona%TYPE default null,
      p_cod_oficina IN ge_clientes.cod_oficina%TYPE default null,
      p_cod_oficial IN ge_clientes.cod_usu_oficial%TYPE default null
   ) IS
      v_existe VARCHAR2(1);
      v_proceso varchar2(20) := null;
   BEGIN
      IF p_cod_persona is not null THEN
         v_proceso := 'CARTERA_TERCEROS';
      END IF;
      SELECT 'S' INTO v_existe FROM ge_clientes WHERE cod_persona = nvl(p_cod_persona, v_cod_persona);

      if v_existe = 'S' then
        update ge_clientes s
        set s.cod_departamento = nvl(s.cod_departamento,'11')
        where cod_persona = nvl(p_cod_persona, v_cod_persona);
       end if;

   EXCEPTION
      WHEN no_data_found THEN
         BEGIN
            INSERT INTO ge_clientes
               (cod_persona, cod_oficina, cod_usu_oficial, exo_impuestos, cli_especial,
                cod_seg_cliente, cod_tip_deudor, residente, cod_departamento, tip_extracto,
                cod_sec_contable, cli_confidencial)
            VALUES
               (nvl(p_cod_persona, v_cod_persona), nvl(p_cod_oficina, v_cod_oficina),
                nvl(p_cod_oficial, v_cod_oficial), 'N', 'N', '2', '2', 'S',
                '11', 'C', 'N', 'N');
         EXCEPTION
            WHEN OTHERS THEN
               v_con_error := 'S';

               pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_GE_CLIENTE',
                          v_fec_actual, v_proceso, v_cod_ente);
         END;

   END;

      -- Procedimiento que verifica usuario quien realiza compra de cartera
   PROCEDURE pr_usu_compras
   (
      p_usuario varchar2,
      p_proceso in number
   ) IS
     v_existe   number;
   BEGIN

      if p_proceso = 32 then
       -- Eliminamos e insertamos el usuario que se encuentra parametrizado para generar compras de carteras
          delete ge_par_dinamicos d
          where d.parametro = 'USU_CAR_COMPRAS';

          insert into ge_par_dinamicos d (parametro,val_parametro)
                               values ('USU_CAR_COMPRAS', p_usuario);
      elsif p_proceso = 33 then
         v_existe := nvl(instr(fug_obt_pardinamico('USU_CAR_COMPRAS'),p_usuario),0);
         if v_existe = 0 then
            update ge_par_dinamicos d
            set d.val_parametro = d.val_parametro||','||p_usuario
            where d.parametro = 'USU_CAR_COMPRAS';
         end if;
      elsif p_proceso = 34 then
                  delete ge_par_dinamicos d
                   where d.parametro = 'USU_CAR_COMPRAS';
      end if;
        commit;
END;

   -- Procedimiento que Inserta Informacion de Actividades Esperadas.
   PROCEDURE pr_ins_cr_act_esperadas IS
      v_existe VARCHAR2(1) := 'N';
   BEGIN

      SELECT DISTINCT 'S' INTO v_existe FROM cr_act_esperadas WHERE cod_persona = v_cod_persona;
   EXCEPTION
      WHEN no_data_found THEN
         BEGIN

            INSERT INTO cr_act_esperadas
               (cod_persona, cod_moneda, can_tra_debito, can_tra_credito, mto_pro_debito,
                mto_pro_credito, fecha)
            VALUES
               (v_cod_persona, 'GS', 1, 1, '20000000', '20000000', v_fec_actual);

         EXCEPTION
            WHEN OTHERS THEN
               v_con_error := 'S';

               pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500),
                          v_com_error || ', PR_INS_CR_ACT_ESPERADAS', v_fec_actual, v_cod_ente);
         END;

   END;

   -- Procedimiento que Inserta Informacion de Origen de Fondos.
   PROCEDURE pr_ins_cr_inf_fondos IS
      v_existe VARCHAR2(1);
   BEGIN

      SELECT 'S' INTO v_existe FROM cr_inf_fondos WHERE cod_persona = v_cod_persona;
   EXCEPTION
      WHEN no_data_found THEN

         BEGIN
            INSERT INTO cr_inf_fondos
               (cod_persona, fon_prestamos, pro_gas_operativos, pep)
            VALUES
               (v_cod_persona, 'S', 'S', 'N');

         EXCEPTION
            WHEN OTHERS THEN
               v_con_error := 'S';

               pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_CR_INF_FONDOS',
                          v_fec_actual, v_cod_ente);
         END;

   END;

   -- Procedimiento que Inserta Informacion de Tipos de Operaciones.
   PROCEDURE pr_ins_cr_per_tip_ope
   (
      p_mto_limite IN NUMBER,
      p_can_cuotas IN NUMBER
   ) IS

      v_fec_vencimiento DATE := add_months(trunc(SYSDATE), (p_can_cuotas * 30));
      v_existe          VARCHAR2(1) := 'N';
   BEGIN

      SELECT 'S' INTO v_existe FROM cr_per_tip_operaciones WHERE cod_persona = v_cod_persona and rownum = 1;
   EXCEPTION
      WHEN no_data_found THEN

         BEGIN

            INSERT INTO cr_per_tip_operaciones
               (cod_persona, cod_modulo, cod_modalidad, cod_moneda, fec_inicio, fec_vencimiento,
                mto_limite)
            VALUES
               (v_cod_persona, v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_fec_inicio,
                v_fec_vencimiento, p_mto_limite);

         EXCEPTION
            WHEN OTHERS THEN
               v_con_error := 'S';

               pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500),
                          v_com_error || ', PR_INS_CR_PER_TIP_OPE', v_fec_actual, v_cod_ente);
         END;

   END;

   ----Procedimiento de Insercion de personas

   PROCEDURE pr_ins_personas
   (
      p_nro_documento  IN ba_personas.nro_documento%TYPE,
      p_tip_documento  IN ba_personas.cod_tip_documento%TYPE,
      p_cod_pais       IN ba_personas.cod_pais%TYPE,
      p_nombre         IN ba_personas.nom_completo%TYPE, --nombre/s
      p_apellido       IN ba_personas.nom_completo%TYPE, --apellido/s
      p_tipo           IN ba_personas.tipo%TYPE,
      p_fec_nacimiento IN ba_per_fisicas.fec_nacimiento%TYPE,
      p_rub_primario   IN ba_personas.cod_rub_primario%TYPE,
      p_cod_persona    IN OUT ba_personas.cod_persona%TYPE,
      p_cod_sexo       IN ba_per_fisicas.cod_sexo%TYPE default null
   )

    IS

      r_bpers       ba_personas%ROWTYPE;
      r_bperf       ba_per_fisicas%ROWTYPE;
      r_bperj       ba_per_juridicas%ROWTYPE;
      v_tip_persona VARCHAR2(3);
      v_nombre      VARCHAR2(200);
      v_apellido    VARCHAR2(200);
      v_fec_vto_documento ba_personas.fec_vto_documento%type;

      /* verifico si el nombre ya existe */
      FUNCTION lp_ver_dup_nombre
      (
         p_tipo    IN VARCHAR2,
         rp_bperf  IN ba_per_fisicas%ROWTYPE,
         rp_bperj  IN ba_per_juridicas%ROWTYPE,
         p_tip_doc NUMBER
      ) RETURN VARCHAR2 IS
         v_cantidad NUMBER := 0;
      BEGIN
         IF p_tipo = 'F' THEN
            --fisico
            SELECT COUNT(*)
              INTO v_cantidad
              FROM ba_per_fisicas b, ba_personas a
             WHERE a.cod_persona = b.cod_persona
               AND b.pri_nombre = rp_bperf.pri_nombre
               AND b.seg_nombre = rp_bperf.seg_nombre
               AND b.pri_apellido = rp_bperf.pri_apellido
               AND b.seg_apellido = rp_bperf.seg_apellido
               AND a.cod_tip_documento = p_tip_doc
               AND rownum = 1;
         ELSE
            SELECT COUNT(*)
              INTO v_cantidad
              FROM ba_per_juridicas b, ba_personas a
             WHERE a.cod_persona = b.cod_persona
               AND b.raz_social = rp_bperj.raz_social
               AND a.cod_tip_documento = p_tip_doc
               AND rownum = 1;
         END IF;
         IF nvl(v_cantidad, 0) > 0 THEN
            RETURN 'S'; -- ya existe un nombre parecido
         ELSE
            RETURN 'N'; -- no existe nombre
         END IF;
      END;

      /*insertar la persona*/
      PROCEDURE lp_ins_ba_personas
      (
         rp_bpers      IN ba_personas%ROWTYPE,
         p_cod_persona IN OUT ba_personas.cod_persona%TYPE
      ) IS
      BEGIN
         BEGIN
            SELECT cod_persona
              INTO p_cod_persona
              FROM ba_personas
             WHERE cod_tip_documento = rp_bpers.cod_tip_documento
               AND nro_documento = rp_bpers.nro_documento;
         EXCEPTION
            WHEN no_data_found THEN
               p_cod_persona := NULL;
         END;
         IF p_cod_persona IS NULL THEN
            --- No existe la persona
            SELECT s_cod_persona.nextval INTO p_cod_persona FROM dual;

            INSERT INTO ba_personas
               (cod_persona, nom_completo, tipo, cod_tip_documento, nro_documento, cod_pais,
                cod_rub_primario, cod_actividad, fec_vto_documento)
            VALUES
               (p_cod_persona, rp_bpers.nom_completo, rp_bpers.tipo, rp_bpers.cod_tip_documento,
                rp_bpers.nro_documento, rp_bpers.cod_pais, rp_bpers.cod_rub_primario,
                fug_obt_cod_actividad(rp_bpers.cod_rub_primario), add_months( pae_cnf.fu_obt_fec_actual('1') ,48));
         ELSE
            --- Existe la persona actualizar datos
            raise_application_error(-20000,
                                    'Persona Existente con Documento ' || rp_bpers.nro_documento);
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            IF SQLCODE <= -20000 THEN
               RAISE;
            ELSE
               raise_application_error(-20000, 'Ins.Persona ' || SQLERRM);
            END IF;
      END;

      /* Insertar persona fisica */
      PROCEDURE lp_ins_ba_per_fisicas
      (
         p_cod_persona IN ba_per_fisicas.cod_persona%TYPE,
         rp_bperf      IN ba_per_fisicas%ROWTYPE
      ) IS
         v_cod_persona ba_personas.cod_persona%TYPE;
      BEGIN
         SELECT cod_persona
           INTO v_cod_persona
           FROM ba_per_fisicas
          WHERE cod_persona = p_cod_persona;
         --- Actualizar
         UPDATE ba_per_fisicas
            SET pri_nombre   = rp_bperf.pri_nombre,
                seg_nombre   = rp_bperf.seg_nombre,
                pri_apellido = rp_bperf.pri_apellido,
                seg_apellido = rp_bperf.seg_apellido
          WHERE cod_persona = p_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            BEGIN
               INSERT INTO ba_per_fisicas
                  (cod_persona, pri_nombre, seg_nombre, pri_apellido, seg_apellido, est_civil,
                   cod_sexo, cod_pai_nacionalidad, fec_nacimiento)
               VALUES
                  (p_cod_persona, rp_bperf.pri_nombre, rp_bperf.seg_nombre, rp_bperf.pri_apellido,
                   rp_bperf.seg_apellido, rp_bperf.est_civil, rp_bperf.cod_sexo,
                   rp_bperf.cod_pai_nacionalidad, rp_bperf.fec_nacimiento);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Ins.ba_per_fisicas' || SQLERRM);
            END;
      END;
      /* Insertar persona Juridica */
      PROCEDURE lp_ins_ba_per_juridicas
      (
         p_cod_persona IN ba_personas.cod_persona%TYPE,
         rp_bperj      IN ba_per_juridicas%ROWTYPE
      ) IS
         v_cod_persona ba_personas.cod_persona%TYPE;
      BEGIN
         SELECT cod_persona
           INTO v_cod_persona
           FROM ba_per_juridicas
          WHERE cod_persona = p_cod_persona;
         --- Actualizar
         UPDATE ba_per_juridicas
            SET raz_social    = rp_bperj.raz_social,
                nom_comercial = rp_bperj.nom_comercial
          WHERE cod_persona = p_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            BEGIN
               INSERT INTO ba_per_juridicas
                  (cod_persona, raz_social, nom_comercial)
               VALUES
                  (p_cod_persona, rp_bperj.raz_social, rp_bperj.nom_comercial);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Ins.ba_per_juridicas' || SQLERRM);
            END;
      END;

      /*procedimiento principal*/
   BEGIN
      BEGIN
         SELECT cod_persona, fec_vto_documento
           INTO p_cod_persona, v_fec_vto_documento
           FROM ba_personas
          WHERE nro_documento = trim(p_nro_documento);
      EXCEPTION
         WHEN OTHERS THEN
            p_cod_persona := 'N';
            v_fec_vto_documento := null;
      END;

      IF p_cod_persona = 'N' THEN
         v_nombre                  := upper(TRIM(p_nombre));
         v_apellido                := upper(TRIM(p_apellido));
         v_tip_persona             := p_tipo;
         r_bpers.nom_completo      := substr(v_nombre || ' ' || v_apellido, 1, 120);
         r_bpers.nro_documento     := upper(TRIM(p_nro_documento));
         r_bpers.cod_tip_documento := p_tip_documento;
         r_bpers.fec_vto_documento := pae_cnf.fu_obt_fec_actual('1');
         r_bpers.cod_rub_primario  := p_rub_primario;
         IF v_tip_persona = 'F' THEN
            r_bpers.tipo                 := 'F';
            r_bperf.fec_nacimiento       := p_fec_nacimiento;
            r_bperf.cod_pai_nacionalidad := p_cod_pais;
            --- Desmembrar nombre
            r_bperf.pri_nombre   := fug_obt_nombre(v_nombre, 1);
            r_bperf.pri_apellido := fug_obt_nombre(v_apellido, 1);
            r_bperf.seg_nombre   := fug_obt_nombre(v_nombre, 2);
            r_bperf.seg_apellido := fug_obt_nombre(v_apellido, 2);
            r_bperf.est_civil    := 'S';
            IF p_cod_sexo is not null THEN
               r_bperf.cod_sexo := p_cod_sexo;
            ELSE
               --determinar sexo
               IF r_bperf.pri_nombre LIKE '%A' OR
                  r_bperf.pri_nombre IN
                  ('CARMEN', 'GLADYS', 'MIRIAN', 'NANCY', 'LOURDES', 'LILIAN', 'MERCEDES', 'IRENE',
                   'ISABEL', 'MARLENE', 'EDITH', 'BEATRIZ', 'NELLY', 'MYRIAN', 'RAQUEL', 'MIRIAM', 'LIZ',
                   'LUZ', 'ELIZABETH', 'GLADIS', 'CLOTILDE', 'CONCEPCION', 'MATILDE', 'RUTH', 'ESTHER',
                   'ESTER', 'MABEL', 'INGRID', 'DOLORES', 'INES') THEN
                  r_bperf.cod_sexo := 'F';
               ELSE
                  r_bperf.cod_sexo := 'M';
               END IF;
            END IF;
         ELSE
            r_bpers.tipo          := 'J';
            r_bperj.raz_social    := TRIM(upper(substr(r_bpers.nom_completo, 1, 120)));
            r_bperj.nom_comercial := TRIM(upper(substr(r_bpers.nom_completo, 1, 65)));
         END IF;
         r_bpers.cod_pais := p_cod_pais;
         IF (r_bperf.pri_nombre IS NULL) AND r_bpers.tipo = 'F' THEN
            raise_application_error(-20001, 'No se permite valores nulos para Primer Nombre');
         ELSIF (r_bperf.pri_apellido IS NULL) AND r_bpers.tipo = 'F' THEN
            raise_application_error(-20002, 'No se permite valores nulos para Primer Apellido');
         ELSIF r_bperj.raz_social IS NULL AND r_bpers.tipo = 'J' THEN
            raise_application_error(-20003, 'No se permite valores nulos para Razon Social');
         ELSIF r_bperj.nom_comercial IS NULL AND r_bpers.tipo = 'J' THEN
            raise_application_error(-20004, 'No se permite valores nulos para Nombre Comercial');
         ELSE

            lp_ins_ba_personas(r_bpers, p_cod_persona);
            IF r_bpers.tipo = 'F' THEN
               lp_ins_ba_per_fisicas(p_cod_persona, r_bperf);
            ELSE
               lp_ins_ba_per_juridicas(p_cod_persona, r_bperj);
            END IF;
         END IF;
      ELSE
           -- Verificamos que la fecha de vto documento no sea nulo,
           -- ya se encuentre vencido
           -- la fecha de documento supere los 20 años
          if v_fec_vto_documento is null or
             v_fec_vto_documento < pae_cnf.fu_obt_fec_actual('1') or
             v_fec_vto_documento > pae_cnf.fu_obt_fec_actual('1') + (20 * 365) then
                begin
                 update ba_personas a
                    set a.fec_vto_documento = (pae_cnf.fu_obt_fec_actual('1') + 1)
                  where a.cod_persona = p_cod_persona;
                exception
                  when others then
                     null;
                end;
           end if;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'Ins.Persona ' || SQLERRM);
         END IF;

   END;

   --Procedimiento Inicial
   PROCEDURE pr_pro_compra(p_tipo IN VARCHAR2 default null) IS
      v_nro_solicitud pr_solicitudes.nro_solicitud%TYPE;
      v_nom_completo  ba_personas.nom_completo%TYPE := NULL;
      v_existe        VARCHAR2(1);
      v_tip_ptmo      VARCHAR2(1);

      /*Actualizar conyuge*/
      PROCEDURE lp_act_conyuge
      (
         p_cod_persona  IN ba_personas.cod_persona%TYPE,
         p_cod_per_cony IN ba_personas.cod_persona%TYPE
      ) IS
         v_cod_per_conyuge ba_personas.cod_persona%TYPE := NULL;
      BEGIN
         BEGIN
            select cod_per_vinculo
              into v_cod_per_conyuge
              from ba_vinculos
             where cod_persona = p_cod_persona
               and tipo = 'E';
         EXCEPTION
            when others then
               v_cod_per_conyuge := null;
         END;
         IF v_cod_per_conyuge is null THEN
            insert into ba_vinculos (cod_persona, cod_per_vinculo, tipo, estado)
            values (p_cod_persona, p_cod_per_cony, 'E', 'A');
         ELSE
            IF v_cod_per_conyuge <> p_cod_per_cony THEN
               v_con_error := 'S';
               pr_ins_log(0, 'ERROR AL ACTUALIZAR VINCULOS. Persona'|| p_cod_persona ||
                          ' posee vinculo de esposo/a con otra persona - ' ||
                          SQLERRM, v_com_error || ', PR_PRO_COMPRA', v_fec_actual, v_cod_ente);
            END IF;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            IF SQLCODE <= -20000 THEN
               RAISE;
            ELSE
               raise_application_error(-20000, 'Act.Conyuge ' || SQLERRM);
            END IF;
      END;

   BEGIN
      v_con_error := 'N';

      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;

      delete pr_log_com_cartera;

      pr_usu_compras(user,32);

      FOR rctas IN ctas LOOP
         IF nvl(v_cod_ente, -1) <> rctas.cod_ente THEN
            pr_del_log ('COMPRA_CARTERAS', rctas.cod_ente);
         END IF;
         v_cod_oficina   := rctas.cod_oficina;
         v_cod_moneda    := rctas.cod_moneda;
         v_observacion   := 'COMPRA DE CARTERA - E:' || rctas.cod_ente || '-' ||
                            fue_obt_nom_ente(rctas.cod_ente) || ' - Lote:' || rctas.nro_lote;
         v_cod_entidad   := rctas.cod_ente;
         v_nro_operacion := rctas.nro_operacion;
         v_com_error     := 'ENTIDAD: ' || rctas.cod_ente || ', LOTE: ' || rctas.nro_lote ||
                            ', OPERACION NRO.: ' || v_nro_operacion;
         v_nom_completo  := rctas.nombre || ' ' || rctas.apellido;
         v_cod_oficial   := rctas.cod_usu_oficial;
         v_cod_ente      := rctas.cod_ente;
         v_cod_pais      := rctas.cod_pais;
         v_fec_ini_operacion := rctas.fec_ini_operacion;
         v_cod_rub_economico := rctas.cod_rub_primario;

         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM ge_entes
             WHERE cod_ente = rctas.cod_ente
               AND tipo = 'CC';
         EXCEPTION
            WHEN no_data_found THEN
               pr_ins_log(0,
              'TIPO DE ENTE NO CORRESPONDE',
              'PR_PRO_COMPRA',
              v_fec_actual,
              v_cod_ente);
               v_con_error := 'S';
         END;

         ---Inserta Persona
         pr_ins_personas(rctas.nro_documento, rctas.cod_tip_documento, rctas.cod_pais, rctas.nombre,
                         rctas.apellido, rctas.tipo, rctas.fec_nacimiento, rctas.cod_rub_primario,
                         v_cod_persona, rctas.cod_sex_cliente);
         ---Inserta Conyuge
         if rctas.nro_doc_conyuge is not null then
            pr_ins_personas(rctas.nro_doc_conyuge, rctas.cod_tip_doc_conyuge, rctas.cod_pais,
                            rctas.nom_conyuge, rctas.ape_conyuge, 'F', null,
                            rctas.cod_rub_primario, v_cod_per_cony, rctas.cod_sex_conyuge);
            lp_act_conyuge (v_cod_persona, v_cod_per_cony);
         end if;
         ---Inserta Codeudor
         if rctas.nro_doc_codeudor is not null then
            pr_ins_personas(rctas.nro_doc_codeudor, rctas.cod_tip_doc_codeudor, rctas.cod_pais,
                            rctas.nom_codeudor, rctas.ape_codeudor, 'F', null,
                            rctas.cod_rub_primario, v_cod_per_codeu, rctas.cod_sex_codeudor);
         end if;
         ---Inserta Conyuge del Codeudor
         if rctas.nro_doc_cony_codeudor is not null then
            pr_ins_personas(rctas.nro_doc_cony_codeudor, rctas.cod_tip_doc_cony_codeudor, rctas.cod_pais,
                            rctas.nom_cony_codeudor, rctas.ape_cony_codeudor, 'F', null,
                            rctas.cod_rub_primario, v_cod_per_cony_codeu, rctas.cod_sex_cony_codeudor);
            lp_act_conyuge (v_cod_per_codeu, v_cod_per_cony_codeu);
         end if;

         ---Inserta Direcciones
         pr_ins_dir_personas(rctas.dir_particular, rctas.dir_laboral, rctas.cod_pais_dir_particular,
                             rctas.cod_pais_dir_laboral, rctas.cod_ciu_dir_particular,
                             rctas.cod_ciu_dir_laboral, rctas.cod_bar_dir_particular,
                             rctas.cod_bar_dir_laboral, rctas.nro_dir_particular,
                             rctas.nro_dir_laboral, rctas.obs_dir_particular, rctas.obs_dir_laboral);
         ---Inserta Telefonos
         pr_ins_tel_personas(rctas.tel_particular, rctas.tel_laboral, rctas.area_tel_particular,
                             rctas.area_tel_laboral, rctas.tip_linea_particular,
                             rctas.tip_linea_laboral);

         if rctas.tipo = 'F' then
         ---Inserta Informacion Laboral
         pr_ins_cr_inf_laboral(rctas.lug_trabajo, rctas.mto_ingreso, rctas.des_puesto,
                               rctas.antiguedad);
         end if;
         ---Inserta Cliente
         pr_ins_ge_cliente(null,v_cod_oficina,null);
         ---Inserta Origen de Fondos
         pr_ins_cr_inf_fondos;
         ---Inserta Actividades Esperadas
         pr_ins_cr_act_esperadas;
         ---Inserta Tipo de Operaciones
         pr_ins_cr_per_tip_ope(rctas.sal_prestamo, rctas.can_cuotas);

         ---Inserta la solicitud
       v_tip_ptmo := fup_obt_tip_pre_com_cartera(rctas.nro_operacion, rctas.cod_ente, rctas.tip_prestamo);
       if rctas.tip_prestamo = 'COMERCIAL' and rctas.sec_publico = 'N' then
          v_cod_modalidad := fug_obt_pardinamico('COM_CAR_INT_ADELANTADO');
          pr_ins_pr_solicitudes(v_cod_persona, v_cod_modalidad,
                                -- tipo de credito
                                v_cod_moneda,
                                -- moneda
                                rctas.sal_prestamo,
                                -- monto del credito
                                rctas.can_cuotas, v_fec_inicio,
                                -- inicio del credito
                                rctas.fec_pri_vencimiento,
                                -- primer vencimiento
                                rctas.val_tasa,
                                -- valor de la tasa
                                rctas.cod_canal,
                                -- codigo del canal
                                rctas.cod_campana,
                                -- codigo de campa?a
                                rctas.descripcion,
                                -- descripcion de la oper.
                                v_usuario, rctas.tip_destino, rctas.cod_banca,
                                rctas.mto_gto_administrativo, rctas.mto_seguro,
                                rctas.cod_rub_economico, v_nom_completo, rctas.cod_tip_documento,
                                rctas.nro_documento, v_nro_solicitud);
        elsif rctas.tip_prestamo = 'CONSUMO' and rctas.sec_publico = 'N' then
          v_cod_modalidad := fug_obt_pardinamico('COM_CAR_INT_VENCIDO');

           pr_ins_pr_sol_vencido(v_cod_persona, v_cod_modalidad,
                                 -- tipo de credito
                                 v_cod_moneda,
                                 -- moneda
                                 rctas.sal_prestamo,
                                 -- monto del credito
                                 rctas.can_cuotas, v_fec_inicio,
                                 -- inicio del credito
                                 rctas.fec_pri_vencimiento,
                                 -- primer vencimiento
                                 rctas.val_tasa,
                                 -- valor de la tasa
                                 rctas.cod_canal,
                                 -- codigo del canal
                                 rctas.cod_campana,
                                 -- codigo de campa?a
                                 rctas.descripcion,
                                 -- descripcion de la oper.
                                 v_usuario, rctas.tip_destino, rctas.cod_banca,
                                 rctas.mto_gto_administrativo, rctas.mto_seguro,
                                 rctas.cod_rub_economico, v_nom_completo, rctas.cod_tip_documento,
                                 rctas.nro_documento, v_nro_solicitud, v_tip_ptmo);
        elsif  rctas.tip_prestamo = 'CONSUMO'  AND rctas.sec_publico = 'S'   THEN
               v_cod_modalidad := fug_obt_pardinamico('COM_CAR_SEC_PUBLICO');

           pr_ins_pr_sol_vencido(v_cod_persona, v_cod_modalidad,
                                 -- tipo de credito
                                 v_cod_moneda,
                                 -- moneda
                                 rctas.sal_prestamo,
                                 -- monto del credito
                                 rctas.can_cuotas, v_fec_inicio,
                                 -- inicio del credito
                                 rctas.fec_pri_vencimiento,
                                 -- primer vencimiento
                                 rctas.val_tasa,
                                 -- valor de la tasa
                                 rctas.cod_canal,
                                 -- codigo del canal
                                 rctas.cod_campana,
                                 -- codigo de campa?a
                                 rctas.descripcion,
                                 -- descripcion de la oper.
                                 v_usuario, rctas.tip_destino, rctas.cod_banca,
                                 rctas.mto_gto_administrativo, rctas.mto_seguro,
                                 rctas.cod_rub_economico, v_nom_completo, rctas.cod_tip_documento,
                                 rctas.nro_documento, v_nro_solicitud, v_tip_ptmo);
        else
                                 v_con_error:='S';
        end if;
        IF v_con_error = 'S' THEN

            pr_ins_log(0, 'ERROR AL SALIR: ' || rctas.nro_operacion,
                       v_com_error || ', PR_PRO_COMPRA',
           v_fec_actual,
           v_cod_ente);
            ---Si existe un error limpiar los datos importados
               /*DELETE FROM pr_cuo_com_cartera c
                WHERE EXISTS (SELECT 1
                         FROM pr_com_cartera p
                        WHERE p.nro_operacion = c.nro_operacion
                          AND p.cod_ente = c.cod_ente
                          AND p.procesado = 'N');
               DELETE FROM pr_com_cartera WHERE procesado = 'N';*/

            EXIT;
         ELSE
            BEGIN
               UPDATE pr_com_cartera
                  SET procesado     = 'S',
                      nro_solicitud = v_nro_solicitud
                WHERE cod_ente = rctas.cod_ente
                  AND nro_operacion = rctas.nro_operacion
                  AND procesado = 'N';

        Exception
          When Others Then
            Raise_Application_Error(-20001,
                                    'Al actualizar ind_pocesado' || Sqlerrm);
            v_Con_Error := 'S';

                  pr_ins_log(0,
                             'ERROR AL ACTUALIZAR PROCESADO: ' ||
           rctas.nro_operacion || ' - ' ||SQLERRM,
           v_com_error || ', PR_PRO_MIGRACION',
           v_fec_actual,
           v_cod_ente);

                  EXIT;
            END;
             --Valida persona Vigia
             DECLARE
              v_parecida VARCHAR2(2);
             BEGIN
               prg_val_alt_per_vigia(v_cod_persona,
                                     v_nom_completo,
                                     rctas.nro_documento,
                                     v_parecida);
             EXCEPTION
               WHEN OTHERS THEN
                 raise_application_error(-20001,'Al validar persona Vigia ' ||SQLERRM);
                 v_con_error := 'S';
                 pr_ins_log(0,
                            'ERROR AL VALIDAR PERSONA VIGIA: ' ||
                            rctas.nro_operacion || ' - ' || SQLERRM,
                            v_com_error || ', PR_PRO_MIGRACION',
                            v_fec_actual,
                            v_cod_ente);
             END;
         END IF;
      END LOOP;

     IF v_con_error = 'S' THEN
         pr_ins_log(0,
            'ERROR AL FINAL: ' || v_nro_operacion || ' - ' || SQLERRM,
                    v_com_error || ', PR_PRO_MIGRACION',
        v_fec_actual,
        v_cod_ente);
         ROLLBACK;

         /*DELETE FROM pr_cuo_com_cartera c
          WHERE EXISTS (SELECT 1
                   FROM pr_com_cartera p
                  WHERE p.nro_operacion = c.nro_operacion
                    AND p.cod_ente = c.cod_ente
                    AND p.procesado = 'N');
         DELETE FROM pr_com_cartera WHERE procesado = 'N';*/

      END IF;
    exception
       when others then
          raise_application_error(-20000, 'ERROR. '||sqlerrm);
   END;

   --Guarda en el log
   PROCEDURE pr_ins_log
   (
      p_nro_error   IN pr_log_com_cartera.nro_error%TYPE, --sqlcode
      p_men_error   IN pr_log_com_cartera.men_error%TYPE, --sqlerrm
      p_com_error   IN pr_log_com_cartera.comentario%TYPE, --Particular
      p_fec_proceso IN pr_log_com_cartera.fec_proceso%TYPE,
      p_proceso     IN VARCHAR2 default null,
      p_cod_ente    in ge_entes.cod_ente%TYPE default null
   ) AS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN

      INSERT INTO pr_log_com_cartera
         (nro_registro, nro_error, men_error, comentario, proceso, fec_proceso)
      VALUES
         (nvl(p_cod_ente, v_nro_registro), p_nro_error, p_men_error, p_com_error, nvl(p_proceso, 'COMPRA_CARTERAS'),
          p_fec_proceso);

      COMMIT;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Al guardar LOG COMPRA CARTERAS' || SQLERRM);
   END;

   -- Limpia las tablas del LOG.
   PROCEDURE pr_del_log
   (
      p_proceso     IN VARCHAR2,
      p_cod_ente    IN pr_log_com_cartera.nro_registro%TYPE
   ) AS
     PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN

      DELETE FROM pr_log_com_cartera
       WHERE fec_proceso = v_fec_actual
         AND proceso = p_proceso
         AND nro_registro = p_cod_ente;

      COMMIT;
   EXCEPTION
      WHEN no_data_found THEN
         NULL;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR - ' || SQLERRM);
   END;

   PROCEDURE pr_ins_pr_solicitudes
   (
      p_cod_persona         IN VARCHAR2, -- codigo de la persona,
      p_cod_modalidad       IN NUMBER, -- tipo de credito
      p_cod_moneda          IN VARCHAR2, -- moneda
      p_monto               IN NUMBER, -- monto del credito
      p_can_cuotas          IN NUMBER, -- nro de cuotas
      p_fec_inicio          IN DATE DEFAULT NULL, -- inicio del credito
      p_fec_pri_vencimiento IN DATE DEFAULT NULL, -- primer vencimiento
      p_val_tasa            IN NUMBER DEFAULT NULL, -- valor de la tasa
      p_cod_canal           IN NUMBER DEFAULT NULL, -- codigo del canal
      p_cod_campana         IN NUMBER DEFAULT NULL, -- codigo de campa?a
      p_descripcion         IN VARCHAR2 DEFAULT NULL, -- descripcion de la oper.
      p_cod_usu_promotor    IN VARCHAR2 DEFAULT NULL,
      p_tip_destino         IN VARCHAR2 DEFAULT NULL,
      p_cod_banca           IN NUMBER DEFAULT NULL,
      p_cargo               IN NUMBER DEFAULT NULL,
      p_seguro              IN NUMBER DEFAULT NULL,
      p_cod_rub_economico   IN pr_rub_economicos.cod_rub_economico%TYPE,
      p_nom_completo        IN ba_personas.nom_completo%TYPE,
      p_tip_documento       IN ba_personas.cod_tip_documento%TYPE,
      p_nro_documento       IN ba_personas.nro_documento%TYPE,
      p_nro_solicitud       OUT pr_solicitudes.nro_solicitud%TYPE
   ) IS
      ------------------ Variables del procedimiento -----------------------------

      v_cotizacion          ge_cotizaciones.val_conversion%TYPE := pag_gen.fu_obt_cotizacion(p_cod_moneda);
      v_per_capital         pr_solicitudes.per_vto_capital%TYPE;
      v_dummy               NUMBER(9);
      v_mon_local           VARCHAR2(3) := pag_gen.fu_obt_mon_local;
      v_lugar               VARCHAR2(200) := NULL;
      v_exo_impuestos       VARCHAR2(1) := 'N';
      v_cod_usu_oficial     VARCHAR2(10);
      v_tot_prestamo        NUMBER(18, 2) := 0; -- total del prestamo
      v_mto_interes         NUMBER(18, 2) := 0; -- total de interes
      v_mto_cargo           NUMBER(18, 2) := 0;
      v_fec_inicio          DATE := nvl(p_fec_inicio, v_fec_actual);
      v_fec_pri_vencimiento DATE := nvl(p_fec_pri_vencimiento, add_months(v_fec_inicio, 1));
      v_fec_vencimiento     DATE := add_months(v_fec_pri_vencimiento, p_can_cuotas - 1);
      v_cod_departamento    NUMBER(3) := NULL; -- Se obtiene de los datos del cliente o en su defecto de la oficina
      v_cod_dep_parametro   NUMBER(3) := NULL; -- Departamento de Parametros
      v_tip_interes         VARCHAR2(1) := 'A'; -- A-Adelantado, V-Vencido
      v_tip_amortizacion    VARCHAR2(1) := 'F'; -- C-Constante, F-Flexible, P-Price
      v_tip_renovacion      VARCHAR2(1) := 'A'; -- A-Nuevo
      v_tip_aju_fecha       VARCHAR2(1) := 'H';
      v_aju_gracia          VARCHAR2(1) := 'S';
      v_tip_documento       NUMBER(1) := 2; -- 1-Vista, 2-Vencimiento
      v_tipo                VARCHAR2(1) := 'D'; -- D-Desc.Docum.
      v_cod_usu_promotor    VARCHAR2(10);
      v_val_tasa            NUMBER := p_val_tasa;
      v_dia_plazo           NUMBER(8);
      v_per_gracia          NUMBER(8);
      v_nro_solicitud       NUMBER(10);
      v_ttvalor             NUMBER(18, 2);
      v_grabar              VARCHAR2(1) := 'S'; -- Definir si grabara o no los datos en las tablas
      v_tip_monto           VARCHAR2(1) := 'B'; -- tipo de monto B-BRUTO o N-NETO
      -- Datos de los cargos -----------------------------------------------------
      v_cod_transaccion NUMBER(4);
      v_cod_tas_cargo   NUMBER(4);
      v_val_tas_cargo   NUMBER;
      v_cod_mon_cargo   VARCHAR2(3);
      v_tpvlpor         VARCHAR2(1);
      v_aplicar         VARCHAR2(3);
      v_tpdetas         VARCHAR2(1);
      v_val_cargo       NUMBER(18, 2);
      v_cod_ent_seguro  NUMBER(6);
      -- control del redondeo ----------------------------------------------------
      v_redondeo     NUMBER(2) := 0; -- redondeo a cero para moneda local
      v_ori_fondo    NUMBER;
      v_fec_inicio2  DATE;

      ------------------ rutinas internas del procedimiento-----------------------

      PROCEDURE pr_val_tasa IS
         CURSOR pizarras IS
            SELECT a.tas_interes, a.tas_minima, a.tas_maxima
              FROM cr_piz_montos b, cr_piz_plazos a
             WHERE a.cod_modulo = v_cod_modulo
               AND a.cod_modalidad = p_cod_modalidad
               AND a.cod_moneda = p_cod_moneda
               AND b.cod_modulo = a.cod_modulo
               AND b.cod_modalidad = a.cod_modalidad
               AND b.cod_moneda = a.cod_moneda
               AND b.mto_desde = a.mto_desde
               AND p_monto BETWEEN b.mto_desde AND b.mto_hasta
               AND v_dia_plazo BETWEEN a.plz_desde AND a.plz_hasta;
         v_tas_interes NUMBER;
         v_tas_minima  NUMBER;
         v_tas_maxima  NUMBER;
      BEGIN
         v_lugar := 'obtener_tasas de pizarras';
         OPEN pizarras;
         FETCH pizarras
            INTO v_tas_interes, v_tas_minima, v_tas_maxima;
         CLOSE pizarras;
         IF v_val_tasa IS NULL THEN
            v_val_tasa := v_tas_interes;
         END IF;

      END;
      -- Verificacion del codigo del cliente-------
      PROCEDURE pr_val_cod_persona IS
      BEGIN
         v_lugar := 'OBTENER_CLIENTE ';
         SELECT exo_impuestos, cod_usu_oficial, cod_usu_promotor, cod_oficina, cod_departamento
           INTO v_exo_impuestos,
                v_cod_usu_oficial,
                v_cod_usu_promotor,
                v_cod_oficina,
                v_cod_departamento
           FROM ba_personas b, ge_clientes g
          WHERE b.cod_persona = g.cod_persona
            AND g.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            BEGIN
               SELECT gen.cod_ofi_matriz, 'N', ciu.cod_departamento
                 INTO v_cod_oficina, v_exo_impuestos, v_cod_departamento
                 FROM ge_par_generales gen, ba_oficinas ofi, ba_ciudades ciu
                WHERE gen.cod_ofi_matriz = ofi.cod_oficina
                  AND ofi.cod_ciudad = ciu.cod_ciudad
                  AND ofi.cod_pais = ciu.cod_pais;
            END;

         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'pr_val_cod_persona',
                       v_fec_actual, v_cod_ente);
      END;
      -- Validacion del tipo de credito---------------------------------------------
      PROCEDURE pr_val_cod_modalidad IS
      BEGIN
         SELECT 0
           INTO v_dummy
           FROM ge_modalidades
          WHERE cod_modulo = v_cod_modulo
            AND cod_modalidad = p_cod_modalidad;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'ERROR. Tipo de Prestamo no habilitado');
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'PR_VAL_COD_MODALIDAD',
                       v_fec_actual, v_cod_ente);
      END;
      -- Validacion del codigo de la moneda-----------------------------------------
      PROCEDURE pr_val_cod_moneda IS
      BEGIN
         SELECT 0 INTO v_dummy FROM ba_monedas WHERE cod_moneda = p_cod_moneda;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'ERROR. Codigo de Moneda inexistente');
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'PR_VAL_COD_MONEDA',
                       v_fec_actual, v_cod_ente);
      END;
      -- Procedimiento para obtener el tipo de tasa --------------------------------
      PROCEDURE pr_obt_tipo_de_tasa
      (
         p_cdtrans IN NUMBER,
         p_cddetas IN OUT NUMBER,
         p_aplicar IN OUT VARCHAR2,
         p_tpvlpor IN OUT VARCHAR2,
         p_tpdetas IN OUT VARCHAR2
      ) IS
      BEGIN
         v_lugar := 'OBTENER TIPO DE TASA ';
         --- 1. Busco la tasa asociada a la transaccion ingresada ---
         SELECT tr.cod_tasa, ta.aplicar, ta.tip_valor, ta.tipo
           INTO p_cddetas, p_aplicar, p_tpvlpor, p_tpdetas
           FROM ge_transacciones tr, ge_tasas ta
          WHERE tr.cod_modulo = v_cod_modulo
            AND tr.cod_modalidad = p_cod_modalidad
            AND tr.cod_transaccion = p_cdtrans
            AND tr.tipo = 'D'
            AND tr.cod_tasa IS NOT NULL
            AND tr.cod_tasa = ta.cod_tasa
            AND EXISTS (SELECT 0
                   FROM ge_transacciones_det
                  WHERE cod_modulo = v_cod_modulo
                    AND cod_modalidad = p_cod_modalidad
                    AND cod_transaccion = 358 /* transaccion de desembolso de prestamos */
                    AND cod_mod_hijo = tr.cod_modulo
                    AND cod_mad_hijo = tr.cod_modalidad
                    AND cod_tra_hijo = tr.cod_transaccion);
         --- 2. Si es la trans. 735 o 736, cobro de seguros por tasa, la tasa es nula ---
         IF p_cdtrans IN (735, 736) THEN
            IF fug_obt_tip_implementacion <> 2 THEN
               p_aplicar := 'CA';
            ELSE
               p_aplicar := 'CI';
            END IF;
            p_tpvlpor := 'I';
            p_tpdetas := 'F';
            p_cddetas := NULL;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'ERROR: Cargo no definido para Prestamos ');
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'PR_OBT_TIPO_DE_TASA',
                       v_fec_actual, v_cod_ente);
      END;
      -- Funcion que obtiene el valor de la tasa fija ------------------------------
      FUNCTION fu_obt_valor_de_tasa_fija
      (
         p_cddetas IN NUMBER,
         p_fcinici IN DATE
      ) RETURN NUMBER IS
         v_vldetas NUMBER(15, 2);
      BEGIN
         v_lugar := 'OBTENER VALOR DE TASA FIJA ';
         -- tasa fija, buscar en tasa por fecha ---
         SELECT val_tasa
           INTO v_vldetas
           FROM ge_tas_fechas f1
          WHERE f1.cod_tasa = p_cddetas
            AND (f1.cod_modalidad IS NULL OR (f1.cod_modalidad = p_cod_modalidad))
            AND (f1.cod_modulo IS NULL OR (f1.cod_modulo = v_cod_modulo))
            AND (f1.cod_moneda IS NULL OR (f1.cod_moneda = p_cod_moneda))
            AND (f1.cod_oficina IS NULL OR (f1.cod_oficina = v_cod_oficina))
            AND f1.nro_cuenta IS NULL
            AND f1.fec_vigencia =
                (SELECT MAX(fec_vigencia)
                   FROM ge_tas_fechas f2
                  WHERE f1.cod_tasa = f2.cod_tasa
                    AND (f2.cod_modalidad IS NULL OR (f2.cod_modalidad = p_cod_modalidad))
                    AND (f2.cod_modulo IS NULL OR (f2.cod_modulo = v_cod_modulo))
                    AND (f2.cod_moneda IS NULL OR (f2.cod_moneda = p_cod_moneda))
                    AND (f2.cod_oficina IS NULL OR (f2.cod_oficina = v_cod_oficina))
                    AND f2.fec_vigencia <= p_fcinici
                    AND f2.nro_cuenta IS NULL);
         RETURN v_vldetas;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN NULL;
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'FU_OBT_VALOR_DE_TASA_FIJA',
                       v_fec_actual, v_cod_ente);
      END;
      -- Funcion que devuelve el valor de la tasa, si es variable ------------------
      FUNCTION fu_obt_valor_de_tasa_variable
      (
         p_cddetas IN NUMBER,
         p_vlmonto IN NUMBER,
         p_fcinici IN DATE
      ) RETURN NUMBER IS
         v_vldetas NUMBER(15, 2);
         CURSOR tv IS
            SELECT tr.val_tasa
              FROM ge_tasas t, ge_tas_rangos tr
             WHERE t.cod_tasa = tr.cod_tasa
               AND t.cod_tasa = p_cddetas
               AND (tr.cod_modulo = v_cod_modulo OR tr.cod_modulo IS NULL)
               AND (tr.cod_modalidad = p_cod_modalidad OR tr.cod_modalidad IS NULL)
               AND (tr.cod_moneda = p_cod_moneda OR tr.cod_moneda IS NULL)
               AND (tr.cod_oficina = v_cod_oficina OR tr.cod_oficina IS NULL)
               AND tr.val_hasta >= p_vlmonto
               AND tr.nro_cuenta IS NULL
               AND tr.fec_vigencia =
                   (SELECT MAX(tra.fec_vigencia)
                      FROM ge_tas_rangos tra
                     WHERE tra.cod_tasa = p_cddetas
                       AND (tra.cod_modulo = v_cod_modulo OR tra.cod_modulo IS NULL)
                       AND (tra.cod_modalidad = p_cod_modalidad OR tra.cod_modalidad IS NULL)
                       AND (tra.cod_moneda = p_cod_moneda OR tra.cod_moneda IS NULL)
                       AND (tra.cod_oficina = v_cod_oficina OR tra.cod_oficina IS NULL)
                       AND tra.val_hasta >= p_vlmonto
                       AND tra.nro_cuenta IS NULL
                       AND tra.fec_vigencia <= p_fcinici)
             ORDER BY val_hasta;
      BEGIN
         v_lugar := 'OBTENER VALOR DE TASA VARIABLE ';
         -- tasa variable, buscar en tabla de tasas variables ---
         OPEN tv;
         FETCH tv
            INTO v_vldetas;
         CLOSE tv;
         IF v_vldetas IS NULL THEN
            raise_application_error(-20000,
                                    'No existe Valor para la Tasa ' || to_char(p_cddetas) ||
                                     ' y el Monto ' || to_char(p_vlmonto) || ' Fecha ' ||
                                     to_char(p_fcinici, 'DD/MM/YYYY'));
         END IF;
         RETURN v_vldetas;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN NULL;
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500),
                       v_com_error || 'FU_OBT_VALOR_DE_TASA_VARIABLE', v_fec_actual, v_cod_ente);
      END;
      -- Verificacion del codigo de tasa--------------------------------------------
      PROCEDURE pr_obt_datos_cargo IS
      BEGIN
         IF v_cod_ent_seguro IS NOT NULL THEN
            --- veo que tasa de seguro tiene el ente asegurador
            v_cod_tas_cargo := fug_obt_parentes(v_cod_ent_seguro, 'COD_TAS_SEGURO');
         END IF;
         -- obtengo los datos de la tasa-----------------
         pr_obt_tipo_de_tasa(v_cod_transaccion, v_cod_tas_cargo, v_aplicar, v_tpvlpor, v_tpdetas);
         --- la tasa es de tipo  valor ---
         IF v_tpdetas = 'F' THEN
            --- tipo de tasa fijo      ---
            v_val_tas_cargo := fu_obt_valor_de_tasa_fija(v_cod_tas_cargo, v_fec_inicio);
         ELSE
            --- tipo de tasa variable  ---
            IF v_aplicar IN ('PI', 'PC', 'PT', 'PL', 'CP', 'IP', 'TP') THEN
               IF v_aplicar IN ('PI', 'PC', 'PT', 'PL') THEN
                  --- El primer rango es por plazo
                  v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo, v_dia_plazo,
                                                                   v_fec_inicio);
               ELSE
                  --- tipo de tasa variable  ---
                  v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                                   nvl(v_tot_prestamo, p_monto),
                                                                   v_fec_inicio);
               END IF;
               IF v_aplicar IN ('CP', 'IP', 'TP') THEN
                  -- aplicar al capital y plazo, busco ahora el valor por plazo
                  v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo, v_dia_plazo,
                                                                   v_fec_inicio);
               ELSIF v_aplicar IN ('PC', 'PT', 'PI') THEN
                  v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                                   nvl(v_tot_prestamo, p_monto),
                                                                   v_fec_inicio);
               END IF;
            ELSE
               v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                                nvl(v_tot_prestamo, p_monto),
                                                                v_fec_inicio);
            END IF;

         END IF;
         IF v_tpvlpor IN ('I', 'P') OR v_cod_transaccion IN (735, 736) THEN
            --- porcentajes  o transacciones de seguros  ---
            v_cod_mon_cargo := v_mon_local;
         ELSE
            --- en caso de que sean valores ----------------
            v_cod_mon_cargo := p_cod_moneda;
            v_val_cargo     := v_val_tas_cargo;
            v_val_tas_cargo := NULL;
         END IF;
      END;

      -- Carga de cargos de la propuesta-------------------------------------------
      PROCEDURE pr_ins_sol_cargos IS
         v_cod_tip_canal ge_tip_canales.cod_tip_canal%TYPE;
         --
         CURSOR cargos IS
            SELECT DISTINCT decode(a.cod_transaccion, 709, 1, 710, 2, a.cod_transaccion) orden, -- solo para ordenamiento
                            a.cod_transaccion,
                            a.cod_ent_seguro,
                            nvl(b.obligatorio, 'N') obligator
              FROM ge_sol_cargos a, ge_transacciones_det b
             WHERE a.cod_transaccion = b.cod_tra_hijo(+)
               AND a.cod_modulo = b.cod_mod_hijo(+)
               AND a.cod_modalidad = b.cod_mad_hijo(+)
               AND a.cod_modulo = v_cod_modulo
               AND a.cod_modalidad = p_cod_modalidad
               AND ((nvl(v_exo_impuestos, 'N') = 'N') OR
                   (nvl(v_exo_impuestos, 'N') = 'S' AND nvl(b.obligatorio, 'N') = 'N'))
               AND (a.cod_canal = p_cod_canal OR
                   (a.cod_canal IS NULL AND NOT EXISTS
                    (SELECT '1' FROM ge_sol_cargos WHERE cod_canal = p_cod_canal)))
               AND (a.cod_tip_canal = v_cod_tip_canal OR
                   (a.cod_tip_canal IS NULL AND NOT EXISTS
                    (SELECT '1' FROM ge_sol_cargos WHERE cod_tip_canal = v_cod_tip_canal)))
               AND (a.cod_campana = p_cod_campana OR
                   (a.cod_campana IS NULL AND NOT EXISTS
                    (SELECT '1' FROM ge_sol_cargos WHERE cod_campana = p_cod_campana)))
             ORDER BY 1;
      BEGIN
         IF p_cod_canal IS NOT NULL THEN
            SELECT cod_tip_canal
              INTO v_cod_tip_canal
              FROM ge_canales
             WHERE cod_canal = p_cod_canal;
         END IF;
         FOR cc IN cargos LOOP
            v_cod_transaccion := cc.cod_transaccion;
            v_cod_ent_seguro  := cc.cod_ent_seguro;
            v_val_tas_cargo   := NULL;
            v_val_cargo       := NULL;
            v_cod_tas_cargo   := NULL;
            v_cod_mon_cargo   := NULL;
            pr_obt_datos_cargo;
            IF cc.cod_transaccion = 704 THEN
               v_val_cargo := p_cargo;
            END IF;
            IF cc.cod_transaccion = 736 THEN
               v_val_cargo := p_seguro;
            END IF;

            IF cc.obligator = 'S' OR nvl(v_val_cargo, 0) != 0 THEN
               INSERT INTO pr_sol_cargos
                  (nro_solicitud, cod_transaccion, fec_tasa, val_tasa, monto, cod_tasa,
                   cod_ent_seguro, cod_moneda, mto_mon_prestamo)
               VALUES
                  (v_nro_solicitud, v_cod_transaccion, v_fec_inicio, v_val_tas_cargo, v_val_cargo,
                   v_cod_tas_cargo, cc.cod_ent_seguro, v_cod_mon_cargo, NULL);
            END IF;
         END LOOP;
      END;

      -- Calculo de los cargos ----------------------------------------------------
      PROCEDURE pr_act_cargos IS
         ww_dfcargos       NUMBER(18, 2);
         v_mto_equivalente NUMBER(18, 2);
         v_cod_tra_ajuste  NUMBER(4);
         v_monto           NUMBER(18, 2);
         CURSOR cargos IS
            SELECT cod_transaccion,
                   cod_tasa,
                   cod_ent_seguro,
                   val_tasa,
                   monto,
                   cod_moneda,
                   mto_mon_prestamo
              FROM pr_sol_cargos
             WHERE nro_solicitud = v_nro_solicitud
               FOR UPDATE OF monto
             ORDER BY decode(cod_transaccion, 709, 1, 710, 2, cod_transaccion);
      BEGIN
         --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
         --- cero los totales de cargo de tipo valor y el total general de cargos -------------
         v_ttvalor        := 0;
         v_mto_cargo      := 0;
         v_cod_tra_ajuste := NULL;
         FOR cc IN cargos LOOP
            v_mto_equivalente := 0;
            -- para realizar ajustes si es necesario----------
            IF v_cod_tra_ajuste IS NULL THEN
               v_cod_tra_ajuste := cc.cod_transaccion;
            END IF;
            -- obtengo los datos de la tasa-----------------
            pr_obt_tipo_de_tasa(cc.cod_transaccion, cc.cod_tasa, v_aplicar, v_tpvlpor, v_tpdetas);
            IF cc.cod_transaccion IS NOT NULL AND
               (cc.cod_moneda IS NULL OR (v_tpvlpor = 'V' AND nvl(cc.monto, 0) = 0)) THEN
               raise_application_error(-20000,
                                       'Valores nulos en Cargos. Verificar la Trans. ' ||
                                        to_char(cc.cod_transaccion));
            END IF;
            IF v_tpvlpor = 'P' THEN
               v_mto_equivalente := 0;
               --- la tasa es un porcentaje-----------------------------------------------------
               IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
                  --- aplicable al interes -----------------------------------------------------
                  v_mto_equivalente := round(v_mto_interes * /* v_DIA_PLAZO * */
                                             cc.val_tasa / 100, v_redondeo);
               END IF;
               IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
                  --- es aplicable al capital --------------------------------------------------
                  v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                       round(v_tot_prestamo * /*v_DIA_PLAZO **/
                                             cc.val_tasa / 100, v_redondeo);
               END IF;
            ELSIF v_tpvlpor = 'I' THEN
               v_mto_equivalente := 0;
               --- la tasa es un impuesto ------------------------------------------------------
               IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
                  --- aplicable al interes -----------------------------------------------------
                  IF v_dia_plazo < 365 THEN
                     v_mto_equivalente := round(v_mto_interes * v_dia_plazo * cc.val_tasa / 36500,
                                                v_redondeo);
                  ELSE
                     v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100, v_redondeo);
                  END IF;
               END IF;
               IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
                  --- es aplicable al capital --------------------------------------------------
                  IF cc.cod_ent_seguro IS NOT NULL THEN
                     --- es un seguro ----------------------------------------------------------
                     v_mto_equivalente := cc.monto;
                  ELSE
                     --- es un impuesto sobre el capital ---------------------------------------
                     IF v_dia_plazo < 365 THEN
                        v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                             round(v_tot_prestamo * v_dia_plazo * cc.val_tasa /
                                                   36500, v_redondeo);
                     ELSE
                        v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                             round(v_tot_prestamo * cc.val_tasa / 100, v_redondeo);
                     END IF;
                  END IF;
               END IF;
            ELSIF v_tpvlpor = 'V' THEN
               --- es un monto valor -----------------------------------------------------------
               v_mto_equivalente := cc.monto;
               v_ttvalor         := nvl(v_ttvalor, 0) + nvl(v_mto_equivalente, 0);
            END IF;
            --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
            v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_equivalente, 0);
            ------------------------------------------------------------------------------------
            v_monto := NULL;
            IF v_tpvlpor IN ('I', 'P') THEN
               /* solo si es porcentaje */
               IF cc.cod_moneda = p_cod_moneda THEN
                  -- moneda del cargo es igual a la moneda de la simulacion ----------------------
                  v_monto := v_mto_equivalente;
               ELSE
                  -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
                  v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
               END IF;
            END IF;
            UPDATE pr_sol_cargos
               SET mto_mon_prestamo = nvl(v_mto_equivalente, 0),
                   monto            = nvl(v_monto, monto)
             WHERE CURRENT OF cargos;
         END LOOP;
         IF v_mto_cargo >= v_tot_prestamo THEN
            raise_application_error(-20000,
                                    'ERROR. Total de Cargos ' || v_mto_cargo ||
                                     ' es superior al Total del Prestamo ' || v_tot_prestamo);
         ELSE
            IF v_tip_monto = 'N' AND v_tot_prestamo <> p_monto THEN
               --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
               IF nvl(v_tot_prestamo, 0) - nvl(v_mto_cargo, 0) <> p_monto THEN
                  -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
                  ww_dfcargos := p_monto - (nvl(v_tot_prestamo, 0) - nvl(v_mto_cargo, 0));
                  --V_MTO_EQUIVALENTE := NVL(V_MTO_EQUIVALENTE, 0) - ww_dfcargos;
                  v_mto_cargo := nvl(v_mto_cargo, 0) - ww_dfcargos;
                  UPDATE pr_sol_cargos
                     SET mto_mon_prestamo = nvl(mto_mon_prestamo, 0) - nvl(ww_dfcargos, 0),
                         monto            = decode(cod_moneda, p_cod_moneda,
                                                   nvl(mto_mon_prestamo, 0) - nvl(ww_dfcargos, 0),
                                                   decode(cod_moneda, v_mon_local,
                                                           round(((nvl(mto_mon_prestamo, 0) -
                                                                  nvl(ww_dfcargos, 0)) * v_cotizacion),
                                                                  v_redondeo),
                                                           round(((nvl(mto_mon_prestamo, 0) -
                                                                  nvl(ww_dfcargos, 0)) * v_cotizacion),
                                                                  v_redondeo)))
                   WHERE nro_solicitud = v_nro_solicitud
                     AND cod_transaccion = v_cod_tra_ajuste;
               END IF;
            END IF;
         END IF;
         -- actualizo el total de cargos de  la solicitud
         UPDATE pr_solicitudes SET mto_cargo = v_mto_cargo WHERE nro_solicitud = v_nro_solicitud;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'CALCULAR_CARGOS ' || SQLERRM);
      END;
      -- INICIO DEL PROCEDIMIENTO PRINCIPAL----------------------------------------
   BEGIN

      ---Busco sector de credito
      SELECT referencia
        INTO v_cod_sec_credito
        FROM pr_rub_economicos
       WHERE cod_rub_economico = p_cod_rub_economico;

      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, p_cod_modalidad, p_cod_moneda);
      -- Valido el codigo del cliente-------------------------------------------
      pr_val_cod_persona;
      -- Valido el codigo de la modalidad que recibo----------------------------
      pr_val_cod_modalidad;
      -- valido la moneda-------------------------------------------------------
      pr_val_cod_moneda;
      -- valido el monto -------------------------------------------------------
      IF nvl(p_monto, 0) <= 0 THEN
         raise_application_error(-20000, 'ERROR. Ingrese Monto del Credito');
      END IF;
      v_tot_prestamo := p_monto;
      -- valido el tipo de monto -----------------------------------------------
      IF nvl(v_tip_monto, 'X') NOT IN ('B', 'N') THEN
         raise_application_error(-20000, 'ERROR. Tipo de Monto debe ser B-Bruto o N-Neto');
      END IF;
      -- valido la cantidad de cuotas ------------------------------------------
      IF nvl(p_can_cuotas, 0) < 1 THEN
         raise_application_error(-20000, 'ERROR. Ingrese la cantidad de cuotas');
      END IF;

      IF nvl(fug_obt_parentes(v_cod_ente, 'CRM_COM_CAR_MOROSA') , 'N') = 'N' THEN
         -- Valido la fecha del primer vencimiento --------------------------------
         IF v_fec_pri_vencimiento <= v_fec_actual AND p_cod_modalidad <> 65 THEN
            raise_application_error(-20000,
                                 'ERROR. Primer Vencimiento debe ser posterior a la fecha de Hoy');
         END IF;
         v_dia_plazo   := add_months(v_fec_pri_vencimiento, p_can_cuotas - 1) - v_fec_inicio;
         v_per_gracia  := v_fec_pri_vencimiento - v_fec_inicio;
         v_per_capital := 30;
         v_fec_inicio2 := v_fec_inicio;
      ELSE
         v_dia_plazo   := add_months(v_fec_pri_vencimiento, p_can_cuotas - 1) - v_fec_ini_operacion;
         v_per_gracia  := v_fec_pri_vencimiento - v_fec_ini_operacion;
         v_per_capital := 30;
         v_fec_inicio2 := v_fec_ini_operacion;
      END IF;

      -- Valido la tasa de interes ---------------------------------------------
      pr_val_tasa;
      -- Asigno el nro de la solicitud -----------------------------------------
      IF v_grabar = 'S' THEN
         SELECT s_nro_sol_prestamos.nextval INTO v_nro_solicitud FROM dual;
      ELSE
         --- Recupero secuencia negativa para solicitud auxiliar
         SELECT s_nro_sol_negativo.nextval INTO v_nro_solicitud FROM dual;
      END IF;
      ---- Origen de Fondos
      IF p_cod_moneda IS NOT NULL AND p_cod_modalidad IS NOT NULL THEN
         v_ori_fondo := nvl(fup_obt_ori_fon_modalidad(p_cod_modalidad, p_cod_moneda), 0);
      END IF;

      IF v_ori_fondo = 0 THEN
         v_ori_fondo := fug_obt_pardinamico('COD_ORI_FON_DESEMB', v_cod_modulo, p_cod_modalidad,
                                            p_cod_moneda, v_cod_oficina);
      END IF;
      -- inserto el registro en la tabla de solicitudes ------------------------
      INSERT INTO pr_solicitudes
         (nro_solicitud, descripcion, monto, tip_interes, tip_amortizacion, dia_plazo,
          fec_vencimiento, mto_interes, per_vto_capital, per_gracia, cod_persona, fec_inicio,
          tip_monto, tot_prestamo, cod_modulo, cod_modalidad, cod_moneda, cod_oficina,
          fec_pri_vencimiento, cod_sec_credito, cod_rub_economico, cod_departamento, tip_documento,
          exo_impuesto, cod_usu_promotor, cod_canal, cod_campana, tip_destino, cod_banca,
          tip_renovacion, cod_ori_fondo, por_ori_fondo, tipo, tip_aju_fecha, aju_gracia,
          est_verificacion, aut_pendiente, estado)
      VALUES
         (v_nro_solicitud, nvl(p_descripcion, '.'), p_monto, v_tip_interes, v_tip_amortizacion,
          /* price */ v_dia_plazo, v_fec_vencimiento, v_mto_interes, v_per_capital, v_per_gracia,
          p_cod_persona, v_fec_inicio2, v_tip_monto, v_tot_prestamo, v_cod_modulo, p_cod_modalidad,
          p_cod_moneda, v_cod_oficina, v_fec_pri_vencimiento, v_cod_sec_credito, p_cod_rub_economico,
          nvl(v_cod_departamento, v_cod_dep_parametro), v_tip_documento /* vista*/, v_exo_impuestos,
          nvl(p_cod_usu_promotor, v_cod_usu_promotor), p_cod_canal, p_cod_campana, p_tip_destino,
          p_cod_banca, v_tip_renovacion, v_ori_fondo, 100, v_tipo, v_tip_aju_fecha, v_aju_gracia,
          'N', 'N', 'S');
      --Inserta el destino Especifico
      pr_ins_pr_sol_destinos(v_nro_solicitud, p_monto);
      --Inserta la Garantia
      pr_ins_pr_sol_garantias(v_nro_solicitud, p_monto);

      --Inserta la tasa de la solicitud
      pr_ins_pr_sol_tasas(v_nro_solicitud, v_val_tasa, v_dia_plazo);

      -- Genero los cargos por defecto
      pr_ins_sol_cargos;

      -- Inserto las cuotas
      pr_ins_pr_sol_cuotas(v_nro_solicitud, p_monto, v_val_tasa, v_mto_interes);
      -- Calculo los cargos ----------------------------------------------------
      pr_act_cargos;

      --Iserta los documentos
      pr_ins_pr_documentos(v_nro_solicitud, p_nro_documento, p_nom_completo, p_tip_documento, p_cod_moneda);

      -- verifico el tipo de prestamo
      IF v_tip_monto = 'B' THEN
         v_tot_prestamo := p_monto;
         UPDATE pr_solicitudes
            SET tot_prestamo    = v_tot_prestamo,
                tot_desembolsar = nvl(v_tot_prestamo, 0) -
                                  (nvl(v_mto_cargo, 0) + nvl(v_mto_interes, 0)),
                mto_interes     = v_mto_interes,
                can_desembolsos = 1
          WHERE nro_solicitud = v_nro_solicitud;

      END IF;
      p_nro_solicitud := v_nro_solicitud;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'Propuesta ' || SQLERRM);
         END IF;
   END;

   -- Procedimiento que Inserta el Destino de la Solicitud.
   PROCEDURE pr_ins_pr_sol_destinos
   (
      p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
      p_monto         IN pr_sol_destinos.monto%TYPE
   ) IS
   v_des_especifico      NUMBER(2) := 3; ---Consumo
   BEGIN

      --Tipo de Destino 3-Consumo
      BEGIN
         INSERT INTO pr_sol_destinos
            (nro_solicitud, tip_des_especifico, monto)
         VALUES
            (p_nro_solicitud, v_des_especifico, p_monto);
      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';

            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_DESTINOS',
                       v_fec_actual, v_cod_ente);
      END;

   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';

         pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_DESTINOS',
                    v_fec_actual, v_cod_ente);
   END;

   -- Procedimiento que Inserta los Documentos de las Cuotas.
   PROCEDURE pr_ins_pr_documentos
   (
      p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
      p_nro_documento IN ba_personas.nro_documento%TYPE,
      p_nom_completo  IN ba_personas.nom_completo%TYPE,
      p_tip_documento IN ba_personas.cod_tip_documento%TYPE,
      p_cod_moneda    IN ba_monedas.cod_moneda%TYPE
   ) IS

      v_nro_cuota pr_sol_cuotas.nro_cuota%TYPE := 0;
      v_existe       VARCHAR2(1) := 'N';
   BEGIN

      BEGIN

         FOR rcuo IN cuo_ctas(v_cod_entidad, v_nro_operacion) LOOP
            v_nro_cuota := v_nro_cuota + 1;
            IF nvl(fug_obt_parentes(v_cod_ente, 'CRM_COM_CAR_MOROSA') , 'N') = 'N' THEN
               INSERT INTO pr_documentos
                  (documento, cod_moneda, monto, fec_emision, fec_vencimiento, nro_referencia,
                   nro_cuota, estado, nro_documento, nom_completo, observaciones, fec_proceso,
                   cod_tip_documento)
               VALUES
                  (v_nro_cuota, v_cod_moneda, rcuo.mto_cuota, v_fec_inicio, rcuo.fec_vencimiento,
                   p_nro_solicitud, v_nro_cuota, 'C', p_nro_documento, p_nom_completo,
                   'CUOTA GENERADA, ' || v_observacion, v_fec_inicio, p_tip_documento);
            ELSE
              IF rcuo.nro_doc_librador is not null THEN
                 ---Inserta Librador
                 pr_ins_personas(rcuo.nro_doc_librador, rcuo.cod_tip_doc_librador, v_cod_pais,
                              rcuo.nom_librador, rcuo.ape_librador, 'F', null,
                              v_cod_rub_economico, v_cod_per_librador, rcuo.cod_sex_librador);

                 v_existe := 'N';
                 BEGIN
                    select 'S'
                      into v_existe
                      from pr_chq_libradores
                     where nro_documento = rcuo.nro_doc_librador
                       and cod_tip_documento = rcuo.cod_tip_doc_librador;
                 EXCEPTION
                    WHEN others THEN
                       v_existe := 'N';
                 END;

                 IF v_existe = 'N' THEN
                    INSERT INTO pr_chq_libradores (nro_documento, nom_completo, fec_ingreso, cod_tip_documento)

                    VALUES (rcuo.nro_doc_librador,  trim(rcuo.nom_librador) ||' '|| trim(rcuo.ape_librador),
                            pae_cnf.fu_obt_fec_actual('1'), rcuo.cod_tip_doc_librador);
                 END IF;

                 v_existe := 'N';
                 BEGIN
                    select 'S'
                      into v_existe
                      from pr_rel_chq_lib
                     where cod_banco = rcuo.cod_banco
                       and nro_cheque = rcuo.nro_cheque
                       and cta_libradora = rcuo.cta_libradora
                       and nro_documento = rcuo.nro_doc_librador
                       and cod_tip_documento = rcuo.cod_tip_doc_librador;
                 EXCEPTION
                    WHEN others THEN
                       v_existe := 'N';
                 END;

                 IF v_existe = 'N' THEN
                    INSERT INTO pr_rel_chq_lib (cod_banco, nro_cheque, cta_libradora, nro_documento,
                                cod_tip_documento)
                    VALUES (rcuo.cod_banco, rcuo.nro_cheque, rcuo.cta_libradora, rcuo.nro_doc_librador,
                                rcuo.cod_tip_doc_librador);
                 END IF;

                 v_existe := 'N';
                 BEGIN
                    select 'S'
                      into v_existe
                      from ge_che_custodias
                     where cod_banco = rcuo.cod_banco
                       and nro_cheque = rcuo.nro_cheque
                       and cta_libradora = rcuo.cta_libradora;
                 EXCEPTION
                    WHEN others THEN
                       v_existe := 'N';
                 END;

                 IF v_existe = 'N' THEN
                    INSERT INTO ge_che_custodias (cod_banco, nro_cheque, cta_libradora, cod_moneda, monto,
                           fec_emision, fec_vencimiento, nro_cuota, estado, tip_servicio, nro_referencia)
                    VALUES (rcuo.cod_banco, rcuo.nro_cheque, rcuo.cta_libradora, p_cod_moneda, rcuo.mto_cheque,
                            rcuo.fec_emision, rcuo.fec_vencimiento, rcuo.nro_cuota, 'I', 'D', p_nro_solicitud);
                 END IF;
              END IF;
            END IF;
         END LOOP;

      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';

            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_DOCUMENTOS',
                       v_fec_actual, v_cod_ente);
      END;

   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';

         pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_DOCUMENTOS',
                    v_fec_actual, v_cod_ente);
   END;

   -- Procedimiento que Inserta las Cuotas de la Solicitud.
   PROCEDURE pr_ins_pr_sol_cuotas
   (
      p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
      p_monto         IN pr_solicitudes.monto%TYPE,
      p_val_tasa      IN pr_sol_tasas.val_tasa%TYPE,
      p_mto_interes   OUT pr_solicitudes.mto_interes%TYPE
   ) IS

      v_val_interes        pr_sol_cuotas.val_interes%TYPE := 0;
      v_val_int_adelantado pr_sol_cuotas.val_int_adelantado%TYPE := 0;
      v_sal_cap_anterior   pr_sol_cuotas.sal_cap_anterior%TYPE := 0;
      v_nro_cuota          pr_sol_cuotas.nro_cuota%TYPE := 0;
      v_cuo_plazo          NUMBER(10) := 0;

   BEGIN

      BEGIN
         DELETE FROM pr_sol_cuotas WHERE nro_solicitud = p_nro_solicitud;
         p_mto_interes := 0;

         FOR rcuo IN cuo_ctas(v_cod_entidad, v_nro_operacion) LOOP
            IF rcuo.fec_vencimiento > v_fec_inicio OR
               nvl(fug_obt_parentes(v_cod_ente, 'CRM_COM_CAR_MOROSA') , 'N') = 'S' THEN
               v_nro_cuota := v_nro_cuota + 1;

               IF nvl(fug_obt_parentes(v_cod_ente, 'CRM_COM_CAR_MOROSA') , 'N') = 'S' THEN
                  v_cuo_plazo := rcuo.fec_vencimiento - v_fec_ini_operacion;
                  v_val_int_adelantado := rcuo.sal_interes;
                  v_val_interes        := v_val_interes + v_val_int_adelantado;
                  p_mto_interes := p_mto_interes + v_val_int_adelantado;
               ELSE
                  v_cuo_plazo := rcuo.fec_vencimiento - v_fec_inicio;
                  v_val_int_adelantado := round(rcuo.mto_cuota * (p_val_tasa / 36500) *
                                            nvl(v_cuo_plazo, 0), 0);
                  v_val_interes        := v_val_interes + v_val_int_adelantado;
                  p_mto_interes := p_mto_interes + v_val_int_adelantado;
               END IF;

               IF v_nro_cuota = 1 THEN
                  v_sal_cap_anterior := p_monto;
               ELSE
                  v_sal_cap_anterior := v_sal_cap_anterior - rcuo.mto_cuota;
               END IF;

               INSERT INTO pr_sol_cuotas
                  (nro_solicitud, nro_cuota, mto_capital, fec_vto_habil, fec_vto_exacto,
                   val_interes, sal_capital, sal_cap_anterior, dia_periodo, dia_interes,
                   val_int_original, val_int_adelantado)
               VALUES
                  (p_nro_solicitud, v_nro_cuota, rcuo.mto_cuota, rcuo.fec_vencimiento,
                   rcuo.fec_vencimiento, 0, 0, v_sal_cap_anterior, v_cuo_plazo, v_cuo_plazo,
                   rcuo.mto_cuota, v_val_int_adelantado);
            ELSE
               v_con_error := 'S';

               pr_ins_log(0,
                          'La Fecha de la Cuota Debe ser Mayor a la Fecha del Proceso. ' ||
                           rcuo.fec_vencimiento || ' - ' || v_fec_inicio,
                          v_com_error || ', PR_INS_PR_DOCUMENTOS', v_fec_actual, v_cod_ente);
            END IF;
         END LOOP;

         INSERT INTO pr_sol_cuotas
            (nro_solicitud, nro_cuota, mto_capital, fec_vto_habil, fec_vto_exacto, val_interes,
             sal_capital, sal_cap_anterior, dia_periodo, dia_interes, val_int_original,
             val_int_adelantado)
         VALUES
            (p_nro_solicitud, 0, 0, v_fec_inicio, v_fec_inicio, v_val_interes, p_monto, 0, 0, 0, 0,
             0);

      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';

            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_CUOTAS',
                       v_fec_actual, v_cod_ente);
      END;

   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';

         pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_CUOTAS',
                    v_fec_actual, v_cod_ente);
   END;

   -- Procedimiento que Inserta las garantias de la Solicitud.
   PROCEDURE pr_ins_pr_sol_garantias
   (
      p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
      p_monto         IN pr_solicitudes.monto%TYPE
   ) IS

   BEGIN

      BEGIN

         INSERT INTO pr_sol_garantias
            (nro_solicitud, cod_garantia, mto_aplicado)
         VALUES
            (p_nro_solicitud, 1, p_monto);

      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';

            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_GARANTIAS',
                       v_fec_actual, v_cod_ente);
      END;

   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';

         pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_GARANTIAS',
                    v_fec_actual, v_cod_ente);
   END;

   -- Procedimiento que Inserta las Tasas de la Solicitud.
   PROCEDURE pr_ins_pr_sol_tasas
   (
      p_nro_solicitud   IN pr_solicitudes.nro_solicitud%TYPE,
      p_val_tasa        IN pr_sol_tasas.val_tasa%TYPE,
      p_per_vencimiento IN pr_sol_tasas.per_vencimiento%TYPE
   ) IS
     v_fec_inicio2  DATE;
   BEGIN
      IF nvl(fug_obt_parentes(v_cod_ente, 'CRM_COM_CAR_MOROSA') , 'N') = 'N' THEN
         v_fec_inicio2 := v_fec_inicio;
      ELSE
         v_fec_inicio2 := v_fec_ini_operacion;
      END IF;
      BEGIN
         INSERT INTO pr_sol_tasas
            (nro_solicitud, fec_vigencia, val_tasa, tip_cobro, per_vencimiento)
         VALUES
            (p_nro_solicitud, v_fec_inicio2, p_val_tasa, 'A', p_per_vencimiento);

      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';

            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_TASAS',
                       v_fec_actual, v_cod_ente);
      END;

   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';

         pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_TASAS',
                    v_fec_actual, v_cod_ente);
   END;

   -- Procedimiento que Actualiza la Solicitud a L - Pendiente de Liquidacion.
   -- Aprobado
   PROCEDURE pr_act_est_solicitudes IS

      v_mto_cargo          pr_solicitudes.mto_cargo%TYPE;
      v_mto_int_adelantado pr_solicitudes.mto_interes%TYPE;
      v_error              NUMBER(10);
      v_mensaje            VARCHAR2(1000);
      v_tae                number(10,2);
      v_tan                number(10,2);

      CURSOR c_sol IS
         SELECT pr_solicitudes.*
           FROM pr_solicitudes, pr_com_cartera
          WHERE pr_solicitudes.nro_solicitud = pr_com_cartera.nro_solicitud
            AND pr_solicitudes.estado = 'S'
            AND pr_com_cartera.procesado = 'S';

   PROCEDURE pr_obt_tas_prestamo(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                                p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE,
                                p_val_tae       IN OUT NUMBER,
                                p_val_tan       IN OUT NUMBER) IS

    v_cta_recalendarizada VARCHAR2(1);
    FUNCTION lf_plz_int_adelantado(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                                   p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE)
      RETURN NUMBER;

    /* Obtener gastos del prestamo. */
    PROCEDURE lp_obt_gas_prestamos(p_nro_solicitud       IN pr_solicitudes.nro_solicitud%TYPE,
                                   p_nro_cuenta          IN pr_cta_prestamos.nro_cuenta%TYPE,
                                   p_cod_moneda          IN ge_cuentas.cod_moneda%TYPE,
                                   p_mto_desembolso      IN pr_solicitudes.monto%TYPE,
                                   p_mto_car_imputable   IN OUT NUMBER,
                                   p_mto_car_noimputable IN OUT NUMBER);
    /* Obtener dias. */
    FUNCTION lf_obt_dias(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                         p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE)
      RETURN NUMBER;

    /* Obtener datos del prestamo. */
    PROCEDURE lp_obt_dat_prestamo(p_nro_solicitud    IN ge_cuentas.nro_cuenta%TYPE,
                                  p_nro_cuenta       IN pr_cta_prestamos.nro_cuenta%TYPE,
                                  p_cod_moneda       IN OUT pr_solicitudes.cod_moneda%TYPE,
                                  p_mto_capital      IN OUT pr_solicitudes.monto%TYPE,
                                  p_tip_interes      IN OUT pr_solicitudes.tip_interes%TYPE,
                                  p_fec_inicio       IN OUT DATE,
                                  p_fec_vencimiento  IN OUT DATE,
                                  p_val_tasa         IN OUT NUMBER,
                                  p_tip_amortizacion IN OUT VARCHAR2,
                                  p_can_cuotas       IN OUT NUMBER,
                                  p_mto_desembolso   IN OUT pr_solicitudes.monto%TYPE,
                                  p_solicitud        IN OUT pr_solicitudes.nro_solicitud%TYPE,
                                  p_tipo             IN OUT pr_solicitudes.tipo%type);

    v_cod_moneda        ge_cuentas.cod_moneda%TYPE;
    v_mto_capital       pr_cta_prestamos.mto_capital%TYPE;
    v_mto_desembolso    pr_cta_prestamos.monto%TYPE;
    v_sal_capital       pr_cta_prestamos.mto_capital%TYPE;
    v_fec_inicio        pr_cta_prestamos.fec_inicio%TYPE;
    v_fec_vencimiento   pr_solicitudes.fec_vencimiento%TYPE;
    v_fec_vto_cuota_ant pr_sol_cuotas.fec_vto_exacto%TYPE;
    v_val_inicial       pr_cta_prestamos.mto_capital%TYPE;
    v_tip_interes       pr_solicitudes.tip_interes%TYPE;
    v_nro_solicitud     pr_solicitudes.nro_solicitud%TYPE;
    v_nro_sol_prestamo  pr_solicitudes.nro_solicitud%TYPE;
    v_nro_cuenta        pr_cta_prestamos.nro_cuenta%type;
    v_es_ia             VARCHAR2(1) := 'N';
    v_acum_tan          NUMBER;
    v_acum_tae          NUMBER;
    v_contador          NUMBER;
    v_gastos_imp        NUMBER;
    v_gastos_noi        NUMBER;
    v_avg_dia           NUMBER;
    v_dif_cuotas        NUMBER;
    v_dif_permitida     NUMBER := 1000;
    v_per_capital       NUMBER;
    v_dias              NUMBER;
    v_dias_cuota        NUMBER;
    v_pri_cuota         NUMBER;
    v_min_cuota         NUMBER;
    v_tot_dias          NUMBER;
    v_mto_gasto         NUMBER(18, 2);
    v_plazo             NUMBER;
    v_can_cuotas        NUMBER;
    v_val_tas_pactada   NUMBER;
    v_redondeo          NUMBER(2) := 0;
    v_periodo           NUMBER := 30;
    v_tip_amortizacion  VARCHAR2(1);
    v_tipo              varchar2(1);
    v_sale              VARCHAR2(1) := 'N';
    v_numero            VARCHAR2(3000);
    v_plz_numero        VARCHAR2(3000);
    v_auxiliar          VARCHAR2(3000);
    v_plz_auxiliar      VARCHAR2(3000);
    v_mto_max_gastos    NUMBER;
    v_mto_lim_prestamo  NUMBER;
    v_dis_gasto         number;

    --- Cursor de cuotas
    CURSOR c_cuotas IS
      SELECT nro_cuota,
             nvl(mto_capital, 0) + nvl(val_interes, 0) val_cuota,
             nvl(mto_capital, 0) mto_capital,
             nvl(val_interes, 0) mto_interes,
             nvl(val_int_adelantado, 0) mto_int_documentado,
             trunc(fec_vto_habil - v_fec_inicio) dias,
             dia_interes,
             fec_vto_exacto,
             nro_solicitud
        FROM pr_sol_cuotas
       WHERE nro_solicitud = p_nro_solicitud
         AND p_nro_cuenta IS NULL
         AND nro_cuota > 0
      UNION ALL
      SELECT nro_cuota,
             nvl(mto_capital, 0) + nvl(mto_int_documentado, 0) +
             nvl(mto_interes, 0) val_cuota,
             nvl(mto_capital, 0) + nvl(mto_int_documentado, 0) mto_capital,
             nvl(mto_interes, 0) mto_interes,
             nvl(mto_int_documentado, 0) mto_int_documentado,
             trunc(fec_vencimiento - v_fec_inicio) dias,
             trunc(fec_vencimiento -
                   decode(nro_cuota,
                          1,
                          v_fec_inicio,
                          pas_bcp.fu_obt_vto_ant_cuo(nro_cuenta, nro_cuota))) dia_interes,
             trunc(fec_vencimiento),
             null
        FROM pr_cuotas
       WHERE nro_cuenta = p_nro_cuenta
         AND p_nro_solicitud IS NULL
         AND nro_cuota > 0
       ORDER BY 1;

    /*Plazo promedio Int. Adelantado */
    function lf_plz_int_adelantado(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                                   p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE)
      return number is
      v_dia_plazo number;
    begin
      if p_nro_solicitud is not null then
        begin
          SELECT case
                   when b.cod_modalidad <> 613 then
                    to_number(nvl(avg(trunc(fec_vto_habil - v_fec_inicio)),
                                  0))
                   else
                    max(b.per_vto_capital)
                 end dias
            into v_dia_plazo
            FROM pr_sol_cuotas a, pr_solicitudes b
           WHERE a.nro_solicitud = p_nro_solicitud
             and b.nro_solicitud = a.nro_solicitud
             AND p_nro_cuenta IS NULL
             AND nro_cuota > 0
           group by b.cod_modalidad;
        exception
          when no_data_found then
            return 0;
        end;
      elsif p_nro_cuenta is not null then
        begin
          SELECT nvl(avg(trunc(fec_vencimiento - v_fec_inicio)), 0) dias
            into v_dia_plazo
            FROM pr_cuotas
           WHERE nro_cuenta = p_nro_cuenta
             AND p_nro_solicitud IS NULL
             AND nro_cuota > 0;
        exception
          when no_data_found then
            return 0;
        end;
      end if;
      return v_dia_plazo;
    exception
      when others then
        return 0;
    end;

    /* Obtener gastos del prestamo. */
    PROCEDURE lp_obt_gas_prestamos(p_nro_solicitud       IN pr_solicitudes.nro_solicitud%TYPE,
                                   p_nro_cuenta          IN pr_cta_prestamos.nro_cuenta%TYPE,
                                   p_cod_moneda          IN ge_cuentas.cod_moneda%TYPE,
                                   p_mto_desembolso      IN pr_solicitudes.monto%TYPE,
                                   p_mto_car_imputable   IN OUT NUMBER,
                                   p_mto_car_noimputable IN OUT NUMBER) IS

      v_fec_actual  DATE;
      v_par_car_tae VARCHAR2(30);
      --V_PAR_MIN_GAS VARCHAR2(30);
      v_gastos            NUMBER;
      v_gastos_imp        NUMBER;
      v_mto_solicitado    number;
      v_aux_mto_imputable number;

      v_mto_lim_prestamo NUMBER;
      v_mto_lim_cargo    NUMBER;
      v_mto_desembolso   NUMBER;
      v_redondeo         NUMBER := 0;
    BEGIN
      v_gastos      := 0;
      v_fec_actual  := pag_cal.fu_obt_fec_actual(4);
      v_par_car_tae := fug_obt_pardinamico('GRU_CAR_TAE');
      IF p_cod_moneda != pag_gen.fu_obt_mon_local THEN
        v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                          NULL,
                                          NULL,
                                          p_cod_moneda);
      END IF;
      IF p_nro_solicitud IS NOT NULL THEN
        --- Obtiene los gastos que constituyen interes.
        SELECT SUM(decode(cod_tra_hijo,
                          NULL,
                          nvl(car.mto_mon_prestamo, 0),
                          round(nvl(car.mto_mon_prestamo, 0) * 100 /
                                (100 + fug_obt_val_tasa(s.cod_modulo,
                                                        s.cod_modalidad,
                                                        s.cod_oficina,
                                                        NULL,
                                                        s.cod_moneda,
                                                        0,
                                                        'N',
                                                        NULL,
                                                        d.cod_tra_hijo,
                                                        s.fec_inicio)),
                                v_redondeo)))
          INTO v_gastos_imp
          FROM ge_transacciones_det d,
               ge_transacciones     t,
               pr_sol_cargos        car,
               pr_solicitudes       s
         WHERE t.cod_transaccion = car.cod_transaccion
           AND t.cod_modulo = s.cod_modulo
           AND t.cod_modalidad = s.cod_modalidad
           AND d.cod_transaccion(+) = t.cod_transaccion
           AND d.cod_modulo(+) = t.cod_modulo
           AND d.cod_modalidad(+) = t.cod_modalidad
           AND car.nro_solicitud = s.nro_solicitud
           AND s.nro_solicitud = p_nro_solicitud
           AND EXISTS --- Solo gastos imputables como interes.
         (SELECT 1
                  FROM ge_gru_transacciones_det gt
                 WHERE gt.cod_transaccion = car.cod_transaccion
                   AND gt.cod_modulo = s.cod_modulo
                   AND gt.cod_modalidad = s.cod_modalidad
                   AND gt.cod_gru_transaccion = v_par_car_tae);

        --- Obtiene los gastos que no constituyen interes.
        --- Obtiene el total de gastos y a este le resta los que si constituyen interes.
        SELECT SUM(nvl(car.mto_mon_prestamo, 0)) - nvl(v_gastos_imp, 0)
          INTO v_gastos
          FROM pr_sol_cargos car
         WHERE car.nro_solicitud = p_nro_solicitud;
        select a.monto
          into v_mto_solicitado
          from pr_solicitudes a
         where a.nro_solicitud = p_nro_solicitud;

      ELSE
        v_gastos         := 0;
        v_gastos_imp     := 0;
        v_mto_solicitado := 0;
      END IF;
      ---
      v_aux_mto_imputable   := round(v_mto_solicitado * 15 / 100, 0);
      p_mto_car_imputable   := nvl(v_gastos_imp, 0);
      p_mto_car_noimputable := nvl(v_gastos, 0);
      ---
      /* Debe hacer todas las comparaciones para verificar si esl gasto es imputable o no. */
      IF p_mto_car_imputable > 0 THEN
        -- Se convierte a la moneda el monto limite para considerar como gastos no imputables...
        v_mto_lim_prestamo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                          p_cod_moneda,
                                                          fug_obt_pardinamico('MTO_TAE',
                                                                              6));

        IF nvl(v_mto_lim_prestamo, 0) > 0 THEN
          -- Solo si el prestamo es menor o igual al limite puede que no sea imputable el cargo.
          IF p_mto_desembolso <= v_mto_lim_prestamo THEN
            -- Si es menor o igual al limite (5.400.000) entonces verifica si el cargo no supera el 15%
            /*IF nvl(p_mto_desembolso,0) > 0 then
              IF p_mto_car_imputable > round(p_mto_desembolso * 0.15, v_redondeo) THEN
                 -- Si el cargo es mayor al 15% se debe considerar como imputable solo el 15%
                 p_mto_car_imputable := p_mto_car_imputable -
                                        round(p_mto_desembolso * 0.15, v_redondeo);
              END IF;
            --ELSE
            END IF;*/
            -- Si sigue siendo mayor a cero.
            IF p_mto_car_imputable > 0 THEN
              -- Si el cargo es menor o igual al 15% debe verificar que no supere el
              -- Se convierte a la moneda el monto limite para considerar como gastos no imputables...
              v_mto_lim_cargo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                             p_cod_moneda,
                                                             fug_obt_pardinamico('IMP_MIN_GAS',
                                                                                 6));

              v_mto_lim_cargo := round((v_mto_lim_cargo / 1.1), v_redondeo);
              IF v_aux_mto_imputable < v_mto_lim_cargo THEN
                v_mto_lim_cargo := v_aux_mto_imputable;
              END IF;
              IF p_mto_car_imputable > v_mto_lim_cargo THEN
                p_mto_car_imputable := p_mto_car_imputable -
                                       v_mto_lim_cargo;
              ELSE
                IF v_gastos_imp = p_mto_car_imputable THEN
                  -- Quiere decir que no se vio afectado por el 15%.
                  p_mto_car_imputable := 0;
                END IF;
              END IF;
            END IF;
            --END IF;
          END IF;
        END IF;
      END IF;
    END;
    /* Obtener dias. */
    FUNCTION lf_obt_dias(p_nro_solicitud IN pr_cta_prestamos.nro_solicitud%TYPE,
                         p_nro_cuota     IN pr_cuotas.nro_cuota%TYPE)
      RETURN NUMBER IS
      v_dias pr_sol_cuotas.dia_interes%TYPE;
    BEGIN
      SELECT dia_interes
        INTO v_dias
        FROM pr_sol_cuotas
       WHERE nro_solicitud = p_nro_solicitud
         AND nro_cuota = p_nro_cuota;
      RETURN v_dias;
    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20000, 'Sol.Cuotas no registrada');
    END;
    /* Obtener datos del prestamo. */
    PROCEDURE lp_obt_dat_prestamo(p_nro_solicitud    IN ge_cuentas.nro_cuenta%TYPE,
                                  p_nro_cuenta       IN pr_cta_prestamos.nro_cuenta%TYPE,
                                  p_cod_moneda       IN OUT pr_solicitudes.cod_moneda%TYPE,
                                  p_mto_capital      IN OUT pr_solicitudes.monto%TYPE,
                                  p_tip_interes      IN OUT pr_solicitudes.tip_interes%TYPE,
                                  p_fec_inicio       IN OUT DATE,
                                  p_fec_vencimiento  IN OUT DATE,
                                  p_val_tasa         IN OUT NUMBER,
                                  p_tip_amortizacion IN OUT VARCHAR2,
                                  p_can_cuotas       IN OUT NUMBER,
                                  p_mto_desembolso   IN OUT pr_solicitudes.monto%TYPE,
                                  p_solicitud        IN OUT pr_solicitudes.nro_solicitud%TYPE,
                                  p_tipo             IN OUT pr_solicitudes.tipo%type) IS
    BEGIN
      SELECT a.cod_moneda,
             a.tot_prestamo,
             a.tip_interes,
             a.fec_inicio,
             a.fec_vencimiento,
             b.val_tasa,
             a.tip_amortizacion,
             can_cuotas,
             a.tot_desembolsar,
             a.nro_solicitud,
             a.tipo
        INTO p_cod_moneda,
             p_mto_capital,
             p_tip_interes,
             p_fec_inicio,
             p_fec_vencimiento,
             p_val_tasa,
             p_tip_amortizacion,
             p_can_cuotas,
             p_mto_desembolso,
             p_solicitud,
             p_tipo
        FROM pr_sol_tasas b,
             pr_solicitudes a,
             (SELECT COUNT(*) can_cuotas
                FROM pr_sol_cuotas
               WHERE nro_cuota > 0
                 AND nro_solicitud = p_nro_solicitud)
       WHERE a.nro_solicitud = p_nro_solicitud
         AND a.nro_solicitud = b.nro_solicitud
         AND p_nro_cuenta IS NULL
      UNION ALL
      SELECT a.cod_moneda,
             a.mto_capital,
             a.tip_interes,
             a.fec_inicio,
             a.fec_vencimiento,
             a.val_tasa,
             nvl(b.tip_amortizacion, 'F') tip_amortizacion,
             a.can_cuotas,
             a.mto_capital,
             a.nro_solicitud,
             a.tipo
        FROM pr_solicitudes b, pr_cta_prestamos a
       WHERE a.nro_cuenta = p_nro_cuenta
         AND p_nro_solicitud IS NULL
         AND a.nro_solicitud = b.nro_solicitud(+);
    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20000,
                                'Solicitud ' || p_nro_solicitud ||
                                ' no registrado');
    END;
    PROCEDURE fu_obt_tir_adelantado(p_interes    IN NUMBER,
                                    p_cargo      IN NUMBER,
                                    p_saldo      IN NUMBER,
                                    p_nro_cuota  IN NUMBER,
                                    p_cod_moneda IN VARCHAR2,
                                    p_tir        OUT NUMBER) IS
      v_sal_minimo NUMBER;
      v_cargo      NUMBER;

    BEGIN
      SELECT PAG_GEN.FU_CON_MON_A_MONEDA(PAG_GEN.FU_OBT_MON_LOCAL,
                                         p_cod_moneda,
                                         sal_min_vigente)
        INTO v_sal_minimo
        FROM pr_parametros;
      v_cargo := round(p_cargo + (p_cargo / 10));
      --Si Capital es mayor a 5 salarios se toma la totalidad del cargo
      IF p_saldo > (v_sal_minimo * 5) THEN
        v_cargo := v_cargo;
        --Si 5 Jornales actuales es menor al 15% del capital
      ELSIF ((v_sal_minimo / 30) * 5) < (p_saldo * 0.15) THEN
        v_cargo := v_cargo - ((v_sal_minimo / 30) * 5);
      ELSE
        v_cargo := v_cargo - (p_saldo * 0.15);
      END IF;
      IF v_cargo < 0 THEN
        v_cargo := 0;
      END IF;
      IF p_nro_cuota = 1 THEN
        p_tir := round((p_interes + v_cargo) / (p_saldo / 100), 2);
      ELSE
        p_tir := round(p_interes / (p_saldo / 100), 2);
      END IF;
    END;
  BEGIN
    v_contador := 0;
    v_acum_tan := 0;
    v_acum_tae := 0;
    -- Para int. adelantado prestamos que no sean de descuento.
    --Si corresponde a una cta. recalendarizada toma el tae informado en el informe de tasas semanal
    BEGIN
      SELECT t.val_parametro, x.val_tas_efectiva, x.val_tas_nominal
        INTO v_cta_recalendarizada, p_val_tae, p_val_tan
        FROM ge_cta_dat_adicionales t, sb_tas_ape_semanales x
       WHERE t.nro_cuenta = p_nro_cuenta
         AND t.parametro IN ('PRE_CTA_RECALENDARIZADA')
         AND t.nro_cuenta = x.nro_cuenta;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_cta_recalendarizada := NULL;
    END;

    IF v_cta_recalendarizada IS NULL THEN
      IF p_nro_cuenta IS NOT NULL THEN
        BEGIN
          SELECT a.tip_interes, a.tipo, b.nro_solicitud
            INTO v_tip_interes, v_tipo, v_nro_sol_prestamo
            FROM pr_solicitudes b, pr_cta_prestamos a
           WHERE a.nro_cuenta = p_nro_cuenta
             AND p_nro_solicitud IS NULL
             AND a.nro_solicitud = b.nro_solicitud(+);
          IF v_tip_interes = 'A' AND v_tipo <> 'D' THEN
            v_es_ia := 'S';
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
            NULL;
          WHEN OTHERS THEN
            NULL;
        END;
      END IF;
      IF v_es_ia = 'S' AND p_nro_cuenta IS NOT NULL THEN
        v_nro_cuenta := NULL;
      ELSIF v_es_ia = 'N' THEN
        v_nro_sol_prestamo := p_nro_solicitud;
        v_nro_cuenta       := p_nro_cuenta;
      END IF;

      --- Obtener datos del prestamos
      lp_obt_dat_prestamo(v_nro_sol_prestamo,
                          v_nro_cuenta,
                          v_cod_moneda,
                          v_mto_capital,
                          v_tip_interes,
                          v_fec_inicio,
                          v_fec_vencimiento,
                          v_val_tas_pactada,
                          v_tip_amortizacion,
                          v_can_cuotas,
                          v_mto_desembolso,
                          v_nro_solicitud,
                          v_tipo);
      lp_obt_gas_prestamos(v_nro_sol_prestamo,
                           v_nro_cuenta,
                           v_cod_moneda,
                           v_mto_desembolso,
                           v_gastos_imp,
                           v_gastos_noi);
      v_sal_capital       := v_mto_capital;
      v_plazo             := v_fec_vencimiento - v_fec_inicio;
      v_fec_vto_cuota_ant := v_fec_inicio;
      v_sale              := 'N';
      v_redondeo          := 0;
      IF v_cod_moneda = pag_gen.fu_obt_mon_local THEN
        v_dif_permitida := 1000;
      ELSE
        v_dif_permitida := 10;
        v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                               NULL,
                                               NULL,
                                               v_cod_moneda);
      END IF;
      -- Obtiene el monto maximo de cobro de comision permitido fuera de TAE.
      v_mto_max_gastos   := NVL(fug_obt_pardinamico('MTO_MAX_COM_ADM',
                                                    NULL,
                                                    NULL,
                                                    v_cod_moneda),
                                0);
      v_mto_max_gastos   := (v_mto_max_gastos / 1.1);
      v_mto_lim_prestamo := pag_gen.fu_con_mon_a_moneda(pag_gen.fu_obt_mon_local,
                                                        v_cod_moneda,
                                                        fug_obt_pardinamico('MTO_TAE',
                                                                            6));
      --
      delete pr_cal_tasas;
      FOR cuo IN c_cuotas LOOP
        /*  El calculo de los prestamos se realizara en dos grupos:
        Descuentos de cheques y documentos
        Otros tipos de prestamos
        Para los prestamos que no son de tipo Desc. de documento, se
        toma siempre como valor inicial el saldo de capital y como
        valor final el mismo saldo mas el interes por cada cuota,
        siendo la cantidad de dias tambien la que corresponde a dicha
        cuota
        La diferencia fundamental radica en los dias que se consideran
        para el calculo: para cada cuota de los prestamos de tipo
        Descuento, siempre se toman los dias desde el inicio del
        prestamo, para el resto de los casos, se toma unicamente
        los dias que corresponden a cada cuota */
        IF cuo.nro_cuota > 0 THEN
          v_numero     := cuo.val_cuota;
          v_plz_numero := cuo.dias;

          IF v_tip_interes != 'A' OR
             (v_tip_interes = 'A' AND v_tipo <> 'D') THEN
            IF cuo.nro_cuota = 1 THEN
              -- Verifica si es realmente price o no.
              IF v_tip_amortizacion = 'P' THEN
                -- Si es price, si los plazos son fijos debe calcular diferente.
                IF p_nro_solicitud IS NOT NULL THEN
                  SELECT AVG(dia_interes),
                         MIN(s.per_vto_capital),
                         AVG(nvl(mto_capital, 0) + nvl(val_interes, 0) +
                             nvl(val_int_adelantado, 0)) -
                         MIN(nvl(mto_capital, 0) + nvl(val_interes, 0) +
                             nvl(val_int_adelantado, 0)),
                         MIN(nvl(mto_capital, 0) + nvl(val_interes, 0) +
                             nvl(val_int_adelantado, 0))
                    INTO v_avg_dia,
                         v_per_capital,
                         v_dif_cuotas,
                         v_min_cuota
                    FROM pr_sol_cuotas c, pr_solicitudes s
                   WHERE s.nro_solicitud = p_nro_solicitud
                     AND c.nro_solicitud = s.nro_solicitud
                     AND c.nro_cuota > 0;
                ELSE
                  SELECT AVG(trunc(x.fec_vencimiento -
                                   pas_bcp.fu_obt_vto_ant_cuo(x.nro_cuenta,
                                                              x.nro_cuota))),
                         MIN(c.per_vto_capital),
                         AVG(nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                             nvl(x.mto_int_documentado, 0)) -
                         MIN(nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                             nvl(x.mto_int_documentado, 0)),
                         MIN(nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                             nvl(x.mto_int_documentado, 0))
                    INTO v_avg_dia,
                         v_per_capital,
                         v_dif_cuotas,
                         v_min_cuota
                    FROM pr_cuotas x, pr_cta_prestamos c
                   WHERE c.nro_cuenta = p_nro_cuenta
                     AND x.nro_cuenta = c.nro_cuenta
                     AND x.nro_cuota > 0;
                END IF;
                IF abs(v_avg_dia - v_per_capital) > 1 OR
                   abs(v_dif_cuotas) > v_dif_permitida OR v_can_cuotas = 1 THEN
                  -- Si la diferencia en dias entre el periodo de interes y el de capital
                  -- se considera que no es periodico por lo tanto no es price.
                  IF abs(cuo.dia_interes - v_per_capital) > 2 OR
                     (abs(v_dif_cuotas) > v_dif_permitida and
                      v_tip_amortizacion <> 'P') OR v_can_cuotas = 1 THEN
                    v_tip_amortizacion := 'F';
                  END IF;
                END IF;
                IF v_tip_implementacion = 2 AND v_tip_amortizacion = 'P' THEN
                  --- Verificar el importe de la primera cuota y del promedio de cuotas
                  BEGIN
                    IF p_nro_solicitud IS NOT NULL THEN
                      SELECT nvl(mto_capital, 0) + nvl(val_interes, 0) +
                             nvl(val_int_adelantado, 0)
                        INTO v_pri_cuota
                        FROM pr_sol_cuotas
                       WHERE nro_solicitud = p_nro_solicitud
                         AND nro_cuota = 1;
                    ELSE
                      SELECT nvl(mto_capital, 0) + nvl(mto_interes, 0) +
                             nvl(mto_int_documentado, 0)
                        INTO v_pri_cuota
                        FROM pr_cuotas
                       WHERE nro_cuenta = p_nro_cuenta
                         AND nro_cuota = 1;
                    END IF;
                  END;
                  --- Para 2 siempre que halla diferencia entra la primera cuota y la minima
                  --- el calculo del tae sera siempre sobre promedio, no se toma en cuenta los
                  --- parametros de diferencia
                  IF v_pri_cuota > v_min_cuota THEN
                    v_tip_amortizacion := 'F';
                  END IF;
                END IF;
              END IF;
            END IF;
          ELSE
            -- Si es adelantado...
            v_tot_dias   := nvl(v_tot_dias, 0) + cuo.dias;
            v_dias_cuota := nvl(v_dias_cuota, 0) +
                            (cuo.fec_vto_exacto - v_fec_vto_cuota_ant);
            IF v_tip_implementacion = 3 THEN
              -- FA.
              v_mto_gasto := round(v_gastos_imp / v_can_cuotas, v_redondeo);
            ELSE
              v_mto_gasto := round(v_gastos_imp *
                                   (nvl(cuo.mto_capital, 0) / v_mto_capital),
                                   v_redondeo);
            END IF;
            IF v_tip_interes != 'A' OR
               (v_tip_interes = 'A' AND v_tipo <> 'D') THEN
              v_val_inicial  := NVL(v_val_inicial, 0) + cuo.mto_capital -
                                cuo.mto_int_documentado - v_mto_gasto;
              v_auxiliar     := v_auxiliar || TRIM(to_char(cuo.val_cuota)) || '#';
              v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias / 365, 4) || '#';
            ELSE
              IF nvl(v_gastos_imp, 0) <> 0 AND
                 nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                 NVL(v_mto_desembolso, 0) <= NVL(v_mto_lim_prestamo, 0) THEN
                v_dis_gasto   := (nvl(v_gastos_imp, 0) -
                                 nvl(v_mto_max_gastos, 0));
                v_val_inicial := nvl(cuo.mto_capital, 0) -
                                 (cuo.mto_interes + cuo.mto_int_documentado) -
                                 ((nvl(v_dis_gasto, 0) / v_can_cuotas));
              ELSIF nvl(v_gastos_imp, 0) <> 0 AND
                    nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                    NVL(v_mto_desembolso, 0) > NVL(v_mto_lim_prestamo, 0) THEN
                v_dis_gasto   := (nvl(v_gastos_imp, 0));
                v_val_inicial := nvl(cuo.mto_capital, 0) -
                                 (cuo.mto_interes + cuo.mto_int_documentado) -
                                 ((nvl(v_dis_gasto, 0) / v_can_cuotas));
              ELSE
                if nvl(v_gastos_imp, 0) <> 0 then
                  v_dis_gasto   := (nvl(v_gastos_imp, 0));
                  v_val_inicial := nvl(cuo.mto_capital, 0) -
                                   (cuo.mto_interes +
                                    cuo.mto_int_documentado) -
                                   ((nvl(v_dis_gasto, 0) / v_can_cuotas));
                else
                  v_dis_gasto   := (nvl(v_gastos_imp, 0));
                  v_val_inicial := nvl(cuo.mto_capital, 0) -
                                   (cuo.mto_interes +
                                    cuo.mto_int_documentado);
                end if;
              END IF;
              --v_val_inicial := cuo.mto_capital - cuo.mto_int_documentado - v_mto_gasto;
              v_auxiliar     := TRIM(to_char(cuo.val_cuota)) || '#';
              v_plz_auxiliar := round(cuo.dias, 4);
            END IF;

            v_numero     := v_auxiliar;
            v_plz_numero := v_plz_auxiliar;
            --v_dias        := cuo.dias;
            if v_tipo = 'D' then
              --v_dias := lf_plz_int_adelantado(p_nro_solicitud, p_nro_cuenta);
              v_dias := cuo.dias;
            else
              v_dias := cuo.dias;
            end if;
          END IF;
          --
          IF v_tip_interes != 'A' OR
             (v_tip_interes = 'A' AND v_tipo <> 'D') THEN
            v_dias := cuo.dia_interes;
            IF v_tip_amortizacion = 'P' THEN
              -- Si sigue siendo price.
              -- Adiciona los gastos a la cuota 1
              IF cuo.nro_cuota = 1 THEN
                IF v_tip_implementacion = 2 THEN
                  v_val_inicial := v_sal_capital - (v_gastos_imp * 2);
                ELSE
                  IF nvl(v_gastos_imp, 0) <> 0 AND
                     nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                     NVL(v_mto_desembolso, 0) <= NVL(v_mto_lim_prestamo, 0) THEN
                    v_val_inicial := v_sal_capital - (nvl(v_gastos_imp, 0) /*- nvl(v_mto_max_gastos,0)*/
                                     );
                  ELSIF nvl(v_gastos_imp, 0) <> 0 AND
                        nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                        NVL(v_mto_desembolso, 0) >
                        NVL(v_mto_lim_prestamo, 0) THEN
                    v_val_inicial := v_sal_capital - (nvl(v_gastos_imp, 0));
                  ELSE
                    v_val_inicial := v_sal_capital - v_gastos_imp;
                  END IF;
                END IF;
                v_dias := v_per_capital;
              END IF;
              -- Debe cargar las cuotas en el auxiliar.
              v_auxiliar     := v_auxiliar ||
                                TRIM(to_char(cuo.mto_capital +
                                             cuo.mto_interes +
                                             cuo.mto_int_documentado)) || '#';
              v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias / 365, 4) || '#';
            ELSE
              -- Sino es price.
              IF cuo.nro_cuota = 1 THEN
                -- Adiciona los gastos a la cuota 1
                IF nvl(v_gastos_imp, 0) <> 0 AND
                   nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                   NVL(v_mto_desembolso, 0) <= NVL(v_mto_lim_prestamo, 0) THEN
                  v_val_inicial := nvl(v_sal_capital, 0) -
                                   (nvl(v_gastos_imp, 0) /*- nvl(v_mto_max_gastos,0)*/);
                ELSIF nvl(v_gastos_imp, 0) <> 0 AND
                      nvl(v_gastos_imp, 0) > nvl(v_mto_max_gastos, 0) AND
                      NVL(v_mto_desembolso, 0) > NVL(v_mto_lim_prestamo, 0) THEN
                  v_val_inicial := nvl(v_sal_capital, 0) -
                                   (nvl(v_gastos_imp, 0));
                ELSE
                  v_val_inicial := nvl(v_sal_capital, 0) -
                                   nvl(v_gastos_imp, 0);
                END IF;
              ELSE
                --v_val_inicial := v_sal_capital;
                if v_tip_interes = 'A' and v_tipo = 'D' then
                  v_val_inicial := nvl(cuo.mto_capital, 0) -
                                   (cuo.mto_interes +
                                    cuo.mto_int_documentado) -
                                   ((nvl(v_dis_gasto, 0) / v_can_cuotas));
                end if;
              END IF;
              v_auxiliar     := v_auxiliar ||
                                TRIM(to_char(cuo.mto_capital +
                                             cuo.mto_interes +
                                             cuo.mto_int_documentado)) || '#';
              v_plz_auxiliar := v_plz_auxiliar || round(cuo.dias / 365, 4) || '#';
            END IF;
            v_numero     := v_auxiliar;
            v_plz_numero := v_plz_auxiliar;
          END IF;
          --- Hace los calculos de TIR, TAN y TAE
          DECLARE
            v_tir     NUMBER;
            v_tan     NUMBER;
            v_tae     NUMBER;
            v_dias1   NUMBER(4);
            v_inicial NUMBER(18, 2);
            v_numero1 VARCHAR2(3000);
            v_numero2 VARCHAR2(3000);
          BEGIN
            v_dias1   := v_dias;
            v_numero1 := v_numero;
            v_numero2 := v_plz_numero;
            v_inicial := v_val_inicial;
            IF v_inicial > 0 THEN
              IF v_tip_amortizacion = 'P' AND v_can_cuotas = cuo.nro_cuota THEN
                -- Si es tipo price en la ultima cuota calcula el tir.
                v_tan := round(pas_bcp.fu_obt_tir(v_inicial,
                                                  v_can_cuotas,
                                                  v_numero1),
                               4);
                v_tae := pas_bcp.fu_obt_tae(v_tan, v_dias);
              ELSIF v_tip_amortizacion != 'P' THEN
                if v_tip_interes = 'A' AND v_tipo <> 'D' then
                  v_dias := abs(cuo.fec_vto_exacto - v_fec_vto_cuota_ant);
                  fu_obt_tir_adelantado(cuo.mto_int_documentado,
                                        v_gastos_imp,
                                        v_sal_capital,
                                        cuo.nro_cuota,
                                        v_cod_moneda,
                                        v_tir);
                else
                  if v_can_cuotas = cuo.nro_cuota and v_tipo <> 'D' then
                    v_tan := round(pas_bcp.fu_obt_val_tir(v_inicial,
                                                          v_can_cuotas,
                                                          v_numero1,
                                                          v_numero2),
                                   4);
                  elsif v_tipo = 'D' then
                    v_tan := round(pas_bcp.fu_obt_tir_ade(v_inicial,
                                                          1,
                                                          v_numero1,
                                                          v_numero2),
                                   4);
                  end if;
                end if;
                v_tae := pas_bcp.fu_obt_tae(v_tan, v_dias);
              END IF;
            ELSE
              v_tir := 0;
              v_tan := 0;
              v_tae := 0;
            END IF;
                       insert into it.PR_CAL_TASAS values (cuo.nro_solicitud,
                                                           cuo.nro_cuota,
                                                           v_tan,
                                                           v_tae,
                                                           v_numero2,
                                                           v_inicial,
                                                           v_numero1);
                                       commit;
            v_acum_tan := nvl(v_acum_tan, 0) + nvl(v_tan, 0);
            v_acum_tae := nvl(v_acum_tae, 0) + nvl(v_tae, 0);
          END;
          v_sal_capital       := v_sal_capital - cuo.mto_capital;
          v_fec_vto_cuota_ant := cuo.fec_vto_exacto;
          v_contador          := v_contador + 1;
          IF v_tip_amortizacion = 'P' or
             (v_tip_amortizacion != 'P' and v_tip_interes <> 'A') THEN
            -- Si es tipo price cera el acumulado porque solo sirve el ultimo calculado y ya no debe calcular el promedio del tan.
            IF v_can_cuotas <> cuo.nro_cuota THEN
              v_acum_tan := 0;
            ELSE
              v_contador := 1;
            END IF;
          END IF;
        END IF;
      END LOOP;
      IF v_tip_interes = 'A' AND v_tipo = 'D' THEN
        v_dias := v_tot_dias / v_contador;
      END IF;
      IF v_dias > 365 THEN
        --- Agregado el 23/06/08 Juan Silvero de BCP dijo que el sistema de tasas no acepta periodo > 365
        v_dias := 365;
      END IF;
      --- Calcular tasa promedio
      p_val_tan := round(v_acum_tan / v_contador, 2);
      IF v_tip_implementacion NOT IN (2, 3) AND
         p_val_tan < v_val_tas_pactada THEN
        p_val_tan := v_val_tas_pactada;
      END IF;

      p_val_tan := round(v_acum_tan, 2);
      p_val_tae := round(v_acum_tae, 2);
      IF v_tip_interes = 'A' AND v_tipo = 'D' THEN
        p_val_tan := round(v_acum_tan / v_contador, 2);
        v_dias    := round(lf_plz_int_adelantado(p_nro_solicitud, p_nro_cuenta));
        p_val_tae := round(fug_obt_tae_ade_com(p_val_tan, v_dias), 2);
      END IF;

    END IF;
  END;

   BEGIN

      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;

      pr_usu_compras(user,33);

      FOR r_sol IN c_sol LOOP
       -- Consultamos si el valor del TAE y TAN están correctos
       pr_obt_tas_prestamo(r_sol.nro_solicitud,null, v_tae, v_tan);

       if nvl(v_tae,0) <> 0 then
         pap_pre.pr_obt_dat_solicitud(r_sol.nro_solicitud, r_sol, v_mto_cargo, v_mto_int_adelantado);
          pap_pre.pr_val_desembolso(r_sol.nro_solicitud, r_sol, v_fec_actual, v_error, v_mensaje);
       else
         v_error := 25;
         v_mensaje := 'Propuesta de credito fuera de Rango en los cálculos de TAN y TAE. Solicitud '||r_sol.nro_solicitud;
       end if;
         IF v_error NOT IN (0, 18) THEN

            pr_ins_log(0, 'ERROR EN LA SOLICITUD : ' || r_sol.nro_solicitud || ' - ' || SQLERRM,
                       v_mensaje || ', PR_ACT_EST_PR_SOLICITUDES', v_fec_actual, v_cod_ente);
            --ROLLBACK;

         ELSE
            SELECT ba_personas.cod_persona
              INTO v_cod_persona
              FROM ba_personas, pr_solicitudes
             WHERE ba_personas.cod_persona = pr_solicitudes.cod_persona
               AND pr_solicitudes.nro_solicitud = r_sol.nro_solicitud;

            UPDATE pr_solicitudes
               SET estado             = 'L',
                   est_verificacion   = 'S',
                   fec_aprobacion     = v_fec_actual,
                   cod_usu_aprobacion = v_usuario
             WHERE nro_solicitud = r_sol.nro_solicitud;

            UPDATE ba_personas
               SET est_verificacion    = 'V',
                   fec_verificacion    = v_fec_actual,
                   cod_usu_verificador = v_usuario
             WHERE cod_persona = v_cod_persona;

         END IF;
          commit;
      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';
         pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_error || ', PR_ACT_EST_PR_SOLICITUDES',
                    v_fec_actual, v_cod_ente);

   END;

   -- Procedimiento de desembolso de la Solicitud.
   PROCEDURE pr_pro_desembolso IS
      v_hora          ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
      v_nro_secuencia ge_movimientos.nro_secuencia%TYPE;
      r_gmovi         ge_movimientos%ROWTYPE;
      v_nro_cuenta    ge_cuentas.nro_cuenta%TYPE;
      v_cotizacion    ge_movimientos.cotizacion%TYPE;
      v_redondeo_ml   NUMBER(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, NULL,
                                                       pag_gen.fu_obt_mon_local);
      v_can_cuotas    pr_sol_cuotas.nro_cuota%TYPE;
      v_rub_contable  ge_movimientos.cod_rubro%TYPE;
      v_des_ente      ge_entes.descripcion%TYPE;
      v_nro_lote      pr_com_cartera.nro_lote%TYPE;
      v_existe        varchar2(2) default 'N';

      CURSOR c_sol IS
         SELECT pr_solicitudes.*, pr_com_cartera.cod_ente, pr_com_cartera.nro_lote, pr_com_cartera.nro_operacion,nvl(pr_com_cartera.ind_recurso,'N') ind_recurso
           FROM pr_solicitudes, pr_com_cartera
          WHERE pr_solicitudes.nro_solicitud = pr_com_cartera.nro_solicitud
            AND pr_solicitudes.estado = 'L';

      CURSOR c_solicitud IS
         SELECT pr_solicitudes.*, pr_com_cartera.cod_ente, pr_com_cartera.nro_lote, pr_com_cartera.nro_operacion,nvl(pr_com_cartera.ind_recurso,'N') ind_recurso
           FROM pr_solicitudes, pr_com_cartera
          WHERE pr_solicitudes.nro_solicitud = pr_com_cartera.nro_solicitud
            AND pr_solicitudes.estado = 'S';

   BEGIN

      FOR r_sol IN c_sol LOOP
         v_nro_secuencia := 0;
         v_hora          := fug_obt_hor_disponible(fue_obt_fec_calendar(6), v_hora, USER, 'N');
         --- Obtiene rubro de ente para desembolso
         if r_sol.cod_moneda =  pag_gen.fu_obt_mon_local then
            v_rub_contable := fug_obt_parentes(r_sol.cod_ente, 'PRE_COD_RUB_COM_CARTERA');
         else
            v_rub_contable := nvl(fug_obt_parentes(r_sol.cod_ente, 'PRE_COD_RUB_COM_CARTERA_ME'),fug_obt_parentes(r_sol.cod_ente, 'PRE_COD_RUB_COM_CARTERA'));
         end if;

         --- Obtiene Descripcion del Ente Compra
         v_des_ente := fue_obt_nom_ente(r_sol.cod_ente);
         --- Obtiene Nro. de lote
         v_nro_lote := r_sol.nro_lote;

         --- Validar el monto a desembolsar
         IF nvl(r_sol.tot_desembolsar, 0) < 0 THEN

            raise_application_error(-20000,
                                    'Monto a desembolsar no puede ser negativo. Debe cancelar los cargos');
         END IF;
         IF v_rub_contable is null THEN
            raise_application_error(-20001,
                                    'Asignar Rubro Contable para Desembolso al parámetro de Ente PRE_COD_RUB_COM_CARTERA');
         END IF;
         SELECT COUNT(*)
           INTO v_can_cuotas
           FROM pr_sol_cuotas
          WHERE nro_solicitud = r_sol.nro_solicitud
            AND nro_cuota > 0;

         v_nro_cuenta := NULL;

         Begin
           pre_ini_aplicacion;
           pae_cnf.g_cod_modulo := 6;
         end;

         -- verificamos si la persona se encuentra inhibida
      if fug_obt_pardinamico('PRO_INH_COMPRAS') = 'S' then
        begin
         Select 'S'
            into v_existe
            from ge_per_inhibidas a
           where a.cod_persona = r_sol.cod_persona
             and a.estado = 'I'
             and rownum = 1;
          exception
            when others then
               v_existe := 'N';
          end;

          if v_existe = 'S' then
             update ge_per_inhibidas i
                set i.estado = 'D'
              where i.estado = 'I'
                and i.cod_persona = r_sol.cod_persona;

             pr_ins_log(NULL, 'PERSONA SE ENCONTRABA INHIBIDA', r_sol.cod_persona,trunc(sysdate));
           end if;
    end if;

         -- Actualiza el comentario...
         -- v_lugar := 'Actualiza Observaciones';
         UPDATE pr_solicitudes pr
            SET pr.observaciones = 'COMPRA DE CARTERA'
          WHERE pr.nro_solicitud = r_sol.nro_solicitud;
         -- Desembolso del Préstamo
         -- v_lugar := 'pap_pre.pr_des_prestamos';
         v_nro_secuencia := v_nro_secuencia + 1;
         pap_pre.pr_des_prestamos(r_sol.nro_solicitud, r_sol.tot_desembolsar,
                                  fue_obt_fec_calendar(6), r_sol.tip_documento, 1, v_can_cuotas,
                                  r_sol.cod_oficina, r_sol.cod_ori_fondo, v_hora, v_nro_secuencia,
                                  v_nro_cuenta);

         --- Verificar cotizacion
         v_cotizacion := NULL;
         IF r_sol.cod_moneda <> pag_gen.fu_obt_mon_local THEN
            ---v_lugar := 'pag_gen.fu_obt_cotizacion';
            v_cotizacion := pag_gen.fu_obt_cotizacion(r_sol.cod_moneda, fue_obt_fec_calendar(6));
         END IF;
         --- Actualizar los desembolsos en etapas
         IF r_sol.tip_renovacion = 'A' AND r_sol.can_desembolsos > 1 THEN
            -- primera solicitud de desembolso en etapas
            UPDATE pr_solicitudes
               SET can_des_faltantes = can_desembolsos - 1
             WHERE nro_solicitud = r_sol.nro_solicitud;
         ELSIF r_sol.tip_renovacion = 'D' THEN
            -- solcitiud de desembolso en etapas (no la primera)
            UPDATE pr_solicitudes
               SET can_des_faltantes = can_des_faltantes - 1
             WHERE nro_solicitud = r_sol.nro_sol_original;
         END IF;

         BEGIN
            -- Referenciar los cheques a la cuenta.
            UPDATE ge_che_custodias
               SET nro_referencia = v_nro_cuenta,
                   estado = 'D'
             WHERE nro_referencia = r_sol.nro_solicitud;
         END;

        -- insertar el nuevo parámetro para compra de cartera
         insert into ge_cta_dat_adicionales(nro_cuenta,parametro,val_parametro)
         values (v_nro_cuenta,'PRE_COM_RECURSO',to_char(r_sol.ind_recurso));
         IF v_rub_contable IS NOT NULL THEN

            r_gmovi.cod_usuario := USER;
            r_gmovi.hora        := v_hora;
            r_gmovi.fecha       := fue_obt_fec_calendar(6);
            -- Aumento la secuencia
            v_nro_secuencia       := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            --
            r_gmovi.cod_modulo      := r_sol.cod_modulo;
            r_gmovi.cod_modalidad   := r_sol.cod_modalidad;
            r_gmovi.cod_oficina     := r_sol.cod_oficina;
            r_gmovi.cod_moneda      := r_sol.cod_moneda;
            r_gmovi.fec_valor       := fue_obt_fec_calendar(6);
            r_gmovi.cod_tra_padre   := 358;
            r_gmovi.cod_mod_padre   := r_sol.cod_modulo;
            r_gmovi.cod_mad_padre   := r_sol.cod_modalidad;
            r_gmovi.cod_transaccion := 741;
            r_gmovi.monto           := r_sol.tot_desembolsar;
            r_gmovi.nro_documento   := r_sol.nro_solicitud;
            r_gmovi.cod_ofi_origen  := r_sol.cod_oficina;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Desembolso de Solicitud ' || r_sol.nro_solicitud;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_rubro       := v_rub_contable;
            r_gmovi.nro_cuenta      := NULL;
            r_gmovi.tip_mov_rubro   := 'C';
            r_gmovi.cotizacion      := v_cotizacion;
            r_gmovi.mto_equ_local   := round(trunc(r_gmovi.monto, 2) * v_cotizacion, v_redondeo_ml);
            pag_gen.pr_ins_ge_movimiento(r_gmovi);
         END IF;
         INSERT INTO ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
         VALUES
            (v_nro_cuenta, 'PRE_COD_ENT_COM_CARTERA', v_des_ente);

         INSERT INTO ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
         VALUES
            (v_nro_cuenta, 'PRE_NRO_LOTE_COM_CARTERA', v_nro_lote);

         INSERT INTO ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
         VALUES
            (v_nro_cuenta, 'CRM_COD_ENTE', r_sol.cod_ente);

         INSERT INTO ge_cta_dat_adicionales
            (nro_cuenta, parametro, val_parametro)
         VALUES
            (v_nro_cuenta, 'CRM_NRO_OPERACION', r_sol.nro_operacion);
      commit;
      END LOOP;

      -- Rechazamos las solicitudes que quedaron inconsistentes
       FOR r_sol IN c_solicitud LOOP
         Begin
           pre_ini_aplicacion;
           pae_cnf.g_cod_modulo := 6;
         end;

            UPDATE pr_solicitudes
               SET estado        = 'R'
             WHERE nro_solicitud = r_sol.nro_solicitud;
             commit;
       end loop;

      pr_usu_compras(user,34);
      ---Posterior al desembolso se trunca las tablas
      EXECUTE IMMEDIATE 'TRUNCATE TABLE PR_CUO_COM_CARTERA';
      EXECUTE IMMEDIATE 'TRUNCATE TABLE PR_COM_CARTERA';

   END pr_pro_desembolso;

  PROCEDURE pr_ins_pr_sol_vencido
   (
      p_cod_persona         IN VARCHAR2, -- codigo de la persona,
      p_cod_modalidad       IN NUMBER, -- tipo de credito
      p_cod_moneda          IN VARCHAR2, -- moneda
      p_monto               IN NUMBER, -- monto del credito
      p_can_cuotas          IN NUMBER, -- nro de cuotas
      p_fec_inicio          IN DATE DEFAULT NULL, -- inicio del credito
      p_fec_pri_vencimiento IN DATE DEFAULT NULL, -- primer vencimiento
      p_val_tasa            IN NUMBER DEFAULT NULL, -- valor de la tasa
      p_cod_canal           IN NUMBER DEFAULT NULL, -- codigo del canal
      p_cod_campana         IN NUMBER DEFAULT NULL, -- codigo de campa?a
      p_descripcion         IN VARCHAR2 DEFAULT NULL, -- descripcion de la oper.
      p_cod_usu_promotor    IN VARCHAR2 DEFAULT NULL,
      p_tip_destino         IN VARCHAR2 DEFAULT NULL,
      p_cod_banca           IN NUMBER DEFAULT NULL,
      p_cargo               IN NUMBER DEFAULT NULL,
      p_seguro              IN NUMBER DEFAULT NULL,
      p_cod_rub_economico   IN pr_rub_economicos.cod_rub_economico%TYPE,
      p_nom_completo        IN ba_personas.nom_completo%TYPE,
      p_tip_documento       IN ba_personas.cod_tip_documento%TYPE,
      p_nro_documento       IN ba_personas.nro_documento%TYPE,
      p_nro_solicitud       OUT pr_solicitudes.nro_solicitud%TYPE,
      p_tip_ptmo            IN pr_solicitudes.tipo%type
   ) IS
      ------------------ Variables del procedimiento -----------------------------

      v_cotizacion          ge_cotizaciones.val_conversion%TYPE := pag_gen.fu_obt_cotizacion(p_cod_moneda);
      v_per_capital         pr_solicitudes.per_vto_capital%TYPE;
      v_dummy               NUMBER(9);
      v_mon_local           VARCHAR2(3) := pag_gen.fu_obt_mon_local;
      v_lugar               VARCHAR2(200) := NULL;
      v_exo_impuestos       VARCHAR2(1) := 'N';
      v_cod_usu_oficial     VARCHAR2(10);
      v_tot_prestamo        NUMBER(18, 2) := 0; -- total del prestamo
      v_mto_interes         NUMBER(18, 2) := 0; -- total de interes
      v_mto_cargo           NUMBER(18, 2) := 0;
      v_fec_inicio          DATE := nvl(p_fec_inicio, v_fec_actual);
      v_fec_pri_vencimiento DATE := nvl(p_fec_pri_vencimiento, add_months(v_fec_inicio, 1));
      v_fec_vencimiento     DATE := add_months(v_fec_pri_vencimiento, p_can_cuotas - 1);
      v_cod_departamento    NUMBER(3) := NULL; -- Se obtiene de los datos del cliente o en su defecto de la oficina
      v_cod_dep_parametro   NUMBER(3) := NULL; -- Departamento de Parametros
      v_tip_interes         VARCHAR2(1) := 'V'; -- A-Adelantado, V-Vencido
      v_tip_amortizacion    VARCHAR2(1) := 'F'; -- C-Constante, F-Flexible, P-Price
      v_tip_renovacion      VARCHAR2(1) := 'A'; -- A-Nuevo
      v_tip_aju_fecha       VARCHAR2(1) := 'E';
      v_aju_gracia          VARCHAR2(1) := 'S';
      v_tip_documento       NUMBER(1) := 2; -- 1-Vista, 2-Vencimiento
      v_tipo                VARCHAR2(1); -- P-Plazo Fijo A-Amortizable
      v_cod_usu_promotor    VARCHAR2(10);
      v_val_tasa            NUMBER := p_val_tasa;
      v_dia_plazo           NUMBER(8);
      v_per_gracia          NUMBER(8);
      v_nro_solicitud       NUMBER(10);
      v_ttvalor             NUMBER(18, 2);
      v_grabar              VARCHAR2(1) := 'S'; -- Definir si grabara o no los datos en las tablas
      v_tip_monto           VARCHAR2(1) := 'B'; -- tipo de monto B-BRUTO o N-NETO
      -- Datos de los cargos -----------------------------------------------------
      v_cod_transaccion NUMBER(4);
      v_cod_tas_cargo   NUMBER(4);
      v_val_tas_cargo   NUMBER;
      v_cod_mon_cargo   VARCHAR2(3);
      v_tpvlpor         VARCHAR2(1);
      v_aplicar         VARCHAR2(3);
      v_tpdetas         VARCHAR2(1);
      v_val_cargo       NUMBER(18, 2);
      v_cod_ent_seguro  NUMBER(6);
      -- control del redondeo ----------------------------------------------------
      v_redondeo     NUMBER(2) := 0; -- redondeo a cero para moneda local
      v_ori_fondo    NUMBER;
      v_fec_inicio2  DATE;
      v_car_calculado NUMBER;

      ------------------ rutinas internas del procedimiento-----------------------

      PROCEDURE pr_val_tasa IS
         CURSOR pizarras IS
            SELECT a.tas_interes, a.tas_minima, a.tas_maxima
              FROM cr_piz_montos b, cr_piz_plazos a
             WHERE a.cod_modulo = v_cod_modulo
               AND a.cod_modalidad = p_cod_modalidad
               AND a.cod_moneda = p_cod_moneda
               AND b.cod_modulo = a.cod_modulo
               AND b.cod_modalidad = a.cod_modalidad
               AND b.cod_moneda = a.cod_moneda
               AND b.mto_desde = a.mto_desde
               AND p_monto BETWEEN b.mto_desde AND b.mto_hasta
               AND v_dia_plazo BETWEEN a.plz_desde AND a.plz_hasta;
         v_tas_interes NUMBER;
         v_tas_minima  NUMBER;
         v_tas_maxima  NUMBER;
      BEGIN
         v_lugar := 'obtener_tasas de pizarras';
         OPEN pizarras;
         FETCH pizarras
            INTO v_tas_interes, v_tas_minima, v_tas_maxima;
         CLOSE pizarras;
         IF v_val_tasa IS NULL THEN
            v_val_tasa := v_tas_interes;
         END IF;

      END;
      -- Verificacion del codigo del cliente-------
      PROCEDURE pr_val_cod_persona IS
      BEGIN
         v_lugar := 'OBTENER_CLIENTE ';
         SELECT exo_impuestos, cod_usu_oficial, cod_usu_promotor, cod_oficina, cod_departamento
           INTO v_exo_impuestos,
                v_cod_usu_oficial,
                v_cod_usu_promotor,
                v_cod_oficina,
                v_cod_departamento
           FROM ba_personas b, ge_clientes g
          WHERE b.cod_persona = g.cod_persona
            AND g.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            BEGIN
               SELECT gen.cod_ofi_matriz, 'N', ciu.cod_departamento
                 INTO v_cod_oficina, v_exo_impuestos, v_cod_departamento
                 FROM ge_par_generales gen, ba_oficinas ofi, ba_ciudades ciu
                WHERE gen.cod_ofi_matriz = ofi.cod_oficina
                  AND ofi.cod_ciudad = ciu.cod_ciudad
                  AND ofi.cod_pais = ciu.cod_pais;
            END;

         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'pr_val_cod_persona',
                       v_fec_actual, v_cod_ente);
      END;
      -- Validacion del tipo de credito---------------------------------------------
      PROCEDURE pr_val_cod_modalidad IS
      BEGIN
         SELECT 0
           INTO v_dummy
           FROM ge_modalidades
          WHERE cod_modulo = v_cod_modulo
            AND cod_modalidad = p_cod_modalidad;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'ERROR. Tipo de Prestamo no habilitado');
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'PR_VAL_COD_MODALIDAD',
                       v_fec_actual, v_cod_ente);
      END;
      -- Validacion del codigo de la moneda-----------------------------------------
      PROCEDURE pr_val_cod_moneda IS
      BEGIN
         SELECT 0 INTO v_dummy FROM ba_monedas WHERE cod_moneda = p_cod_moneda;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'ERROR. Codigo de Moneda inexistente');
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'PR_VAL_COD_MONEDA',
                       v_fec_actual, v_cod_ente);
      END;
      -- Procedimiento para obtener el tipo de tasa --------------------------------
      PROCEDURE pr_obt_tipo_de_tasa
      (
         p_cdtrans IN NUMBER,
         p_cddetas IN OUT NUMBER,
         p_aplicar IN OUT VARCHAR2,
         p_tpvlpor IN OUT VARCHAR2,
         p_tpdetas IN OUT VARCHAR2
      ) IS
      BEGIN
         v_lugar := 'OBTENER TIPO DE TASA ';
         --- 1. Busco la tasa asociada a la transaccion ingresada ---
         SELECT tr.cod_tasa, ta.aplicar, ta.tip_valor, ta.tipo
           INTO p_cddetas, p_aplicar, p_tpvlpor, p_tpdetas
           FROM ge_transacciones tr, ge_tasas ta
          WHERE tr.cod_modulo = v_cod_modulo
            AND tr.cod_modalidad = p_cod_modalidad
            AND tr.cod_transaccion = p_cdtrans
            AND tr.tipo = 'D'
            AND tr.cod_tasa IS NOT NULL
            AND tr.cod_tasa = ta.cod_tasa
            AND EXISTS (SELECT 0
                   FROM ge_transacciones_det
                  WHERE cod_modulo = v_cod_modulo
                    AND cod_modalidad = p_cod_modalidad
                    AND cod_transaccion = 358 /* transaccion de desembolso de prestamos */
                    AND cod_mod_hijo = tr.cod_modulo
                    AND cod_mad_hijo = tr.cod_modalidad
                    AND cod_tra_hijo = tr.cod_transaccion);
         --- 2. Si es la trans. 735 o 736, cobro de seguros por tasa, la tasa es nula ---
         IF p_cdtrans IN (735, 736) THEN
            IF fug_obt_tip_implementacion <> 2 THEN
               p_aplicar := 'CA';
            ELSE
               p_aplicar := 'CI';
            END IF;
            p_tpvlpor := 'I';
            p_tpdetas := 'F';
            p_cddetas := NULL;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'ERROR: Cargo no definido para Prestamos ');
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'PR_OBT_TIPO_DE_TASA',
                       v_fec_actual, v_cod_ente);
      END;
      -- Funcion que obtiene el valor de la tasa fija ------------------------------
      FUNCTION fu_obt_valor_de_tasa_fija
      (
         p_cddetas IN NUMBER,
         p_fcinici IN DATE
      ) RETURN NUMBER IS
         v_vldetas NUMBER(15, 2);
      BEGIN
         v_lugar := 'OBTENER VALOR DE TASA FIJA ';
         -- tasa fija, buscar en tasa por fecha ---
         SELECT val_tasa
           INTO v_vldetas
           FROM ge_tas_fechas f1
          WHERE f1.cod_tasa = p_cddetas
            AND (f1.cod_modalidad IS NULL OR (f1.cod_modalidad = p_cod_modalidad))
            AND (f1.cod_modulo IS NULL OR (f1.cod_modulo = v_cod_modulo))
            AND (f1.cod_moneda IS NULL OR (f1.cod_moneda = p_cod_moneda))
            AND (f1.cod_oficina IS NULL OR (f1.cod_oficina = v_cod_oficina))
            AND f1.nro_cuenta IS NULL
            AND f1.fec_vigencia =
                (SELECT MAX(fec_vigencia)
                   FROM ge_tas_fechas f2
                  WHERE f1.cod_tasa = f2.cod_tasa
                    AND (f2.cod_modalidad IS NULL OR (f2.cod_modalidad = p_cod_modalidad))
                    AND (f2.cod_modulo IS NULL OR (f2.cod_modulo = v_cod_modulo))
                    AND (f2.cod_moneda IS NULL OR (f2.cod_moneda = p_cod_moneda))
                    AND (f2.cod_oficina IS NULL OR (f2.cod_oficina = v_cod_oficina))
                    AND f2.fec_vigencia <= p_fcinici
                    AND f2.nro_cuenta IS NULL);
         RETURN v_vldetas;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN NULL;
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || 'FU_OBT_VALOR_DE_TASA_FIJA',
                       v_fec_actual, v_cod_ente);
      END;
      -- Funcion que devuelve el valor de la tasa, si es variable ------------------
      FUNCTION fu_obt_valor_de_tasa_variable
      (
         p_cddetas IN NUMBER,
         p_vlmonto IN NUMBER,
         p_fcinici IN DATE
      ) RETURN NUMBER IS
         v_vldetas NUMBER(15, 2);
         CURSOR tv IS
            SELECT tr.val_tasa
              FROM ge_tasas t, ge_tas_rangos tr
             WHERE t.cod_tasa = tr.cod_tasa
               AND t.cod_tasa = p_cddetas
               AND (tr.cod_modulo = v_cod_modulo OR tr.cod_modulo IS NULL)
               AND (tr.cod_modalidad = p_cod_modalidad OR tr.cod_modalidad IS NULL)
               AND (tr.cod_moneda = p_cod_moneda OR tr.cod_moneda IS NULL)
               AND (tr.cod_oficina = v_cod_oficina OR tr.cod_oficina IS NULL)
               AND tr.val_hasta >= p_vlmonto
               AND tr.nro_cuenta IS NULL
               AND tr.fec_vigencia =
                   (SELECT MAX(tra.fec_vigencia)
                      FROM ge_tas_rangos tra
                     WHERE tra.cod_tasa = p_cddetas
                       AND (tra.cod_modulo = v_cod_modulo OR tra.cod_modulo IS NULL)
                       AND (tra.cod_modalidad = p_cod_modalidad OR tra.cod_modalidad IS NULL)
                       AND (tra.cod_moneda = p_cod_moneda OR tra.cod_moneda IS NULL)
                       AND (tra.cod_oficina = v_cod_oficina OR tra.cod_oficina IS NULL)
                       AND tra.val_hasta >= p_vlmonto
                       AND tra.nro_cuenta IS NULL
                       AND tra.fec_vigencia <= p_fcinici)
             ORDER BY val_hasta;
      BEGIN
         v_lugar := 'OBTENER VALOR DE TASA VARIABLE ';
         -- tasa variable, buscar en tabla de tasas variables ---
         OPEN tv;
         FETCH tv
            INTO v_vldetas;
         CLOSE tv;
         IF v_vldetas IS NULL THEN
            raise_application_error(-20000,
                                    'No existe Valor para la Tasa ' || to_char(p_cddetas) ||
                                     ' y el Monto ' || to_char(p_vlmonto) || ' Fecha ' ||
                                     to_char(p_fcinici, 'DD/MM/YYYY'));
         END IF;
         RETURN v_vldetas;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN NULL;
         WHEN OTHERS THEN
            v_con_error := 'S';
            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500),
                       v_com_error || 'FU_OBT_VALOR_DE_TASA_VARIABLE', v_fec_actual, v_cod_ente);
      END;
      -- Verificacion del codigo de tasa--------------------------------------------
      PROCEDURE pr_obt_datos_cargo IS
      BEGIN
         IF v_cod_ent_seguro IS NOT NULL THEN
            --- veo que tasa de seguro tiene el ente asegurador
            v_cod_tas_cargo := fug_obt_parentes(v_cod_ent_seguro, 'COD_TAS_SEGURO');
         END IF;
         -- obtengo los datos de la tasa-----------------
         pr_obt_tipo_de_tasa(v_cod_transaccion, v_cod_tas_cargo, v_aplicar, v_tpvlpor, v_tpdetas);
         --- la tasa es de tipo  valor ---
         IF v_tpdetas = 'F' THEN
            --- tipo de tasa fijo      ---
            v_val_tas_cargo := fu_obt_valor_de_tasa_fija(v_cod_tas_cargo, v_fec_inicio);
         ELSE
            --- tipo de tasa variable  ---
            IF v_aplicar IN ('PI', 'PC', 'PT', 'PL', 'CP', 'IP', 'TP') THEN
               IF v_aplicar IN ('PI', 'PC', 'PT', 'PL') THEN
                  --- El primer rango es por plazo
                  v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo, v_dia_plazo,
                                                                   v_fec_inicio);
               ELSE
                  --- tipo de tasa variable  ---
                  v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                                   nvl(v_tot_prestamo, p_monto),
                                                                   v_fec_inicio);
               END IF;
               IF v_aplicar IN ('CP', 'IP', 'TP') THEN
                  -- aplicar al capital y plazo, busco ahora el valor por plazo
                  v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo, v_dia_plazo,
                                                                   v_fec_inicio);
               ELSIF v_aplicar IN ('PC', 'PT', 'PI') THEN
                  v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_val_tas_cargo,
                                                                   nvl(v_tot_prestamo, p_monto),
                                                                   v_fec_inicio);
               END IF;
            ELSE
               v_val_tas_cargo := fu_obt_valor_de_tasa_variable(v_cod_tas_cargo,
                                                                nvl(v_tot_prestamo, p_monto),
                                                                v_fec_inicio);
            END IF;

         END IF;
         IF v_tpvlpor IN ('I', 'P') OR v_cod_transaccion IN (735, 736) THEN
            --- porcentajes  o transacciones de seguros  ---
            v_cod_mon_cargo := v_mon_local;
         ELSE
            --- en caso de que sean valores ----------------
            v_cod_mon_cargo := p_cod_moneda;
            v_val_cargo     := v_val_tas_cargo;
            v_val_tas_cargo := NULL;
         END IF;
      END;

      -- Carga de cargos de la propuesta-------------------------------------------
      PROCEDURE pr_ins_sol_cargos(p_car_calculado in number) IS
         v_cod_tip_canal ge_tip_canales.cod_tip_canal%TYPE;
         --
         CURSOR cargos IS
            SELECT DISTINCT decode(a.cod_transaccion, 709, 1, 710, 2, a.cod_transaccion) orden, -- solo para ordenamiento
                            a.cod_transaccion,
                            a.cod_ent_seguro,
                            nvl(b.obligatorio, 'N') obligator
              FROM ge_sol_cargos a, ge_transacciones_det b
             WHERE a.cod_transaccion = b.cod_tra_hijo(+)
               AND a.cod_modulo = b.cod_mod_hijo(+)
               AND a.cod_modalidad = b.cod_mad_hijo(+)
               AND a.cod_modulo = v_cod_modulo
               AND a.cod_modalidad = p_cod_modalidad
               AND ((nvl(v_exo_impuestos, 'N') = 'N') OR
                   (nvl(v_exo_impuestos, 'N') = 'S' AND nvl(b.obligatorio, 'N') = 'N'))
               AND (a.cod_canal = p_cod_canal OR
                   (a.cod_canal IS NULL AND NOT EXISTS
                    (SELECT '1' FROM ge_sol_cargos WHERE cod_canal = p_cod_canal)))
               AND (a.cod_tip_canal = v_cod_tip_canal OR
                   (a.cod_tip_canal IS NULL AND NOT EXISTS
                    (SELECT '1' FROM ge_sol_cargos WHERE cod_tip_canal = v_cod_tip_canal)))
               AND (a.cod_campana = p_cod_campana OR
                   (a.cod_campana IS NULL AND NOT EXISTS
                    (SELECT '1' FROM ge_sol_cargos WHERE cod_campana = p_cod_campana)))
             ORDER BY 1;
      BEGIN
         IF p_cod_canal IS NOT NULL THEN
            SELECT cod_tip_canal
              INTO v_cod_tip_canal
              FROM ge_canales
             WHERE cod_canal = p_cod_canal;
         END IF;
         FOR cc IN cargos LOOP
            v_cod_transaccion := cc.cod_transaccion;
            v_cod_ent_seguro  := cc.cod_ent_seguro;
            v_val_tas_cargo   := NULL;
            v_val_cargo       := NULL;
            v_cod_tas_cargo   := NULL;
            v_cod_mon_cargo   := NULL;
            pr_obt_datos_cargo;

            IF cc.cod_transaccion = 704 THEN
               v_val_cargo := p_cargo + NVL(p_car_calculado,0);
            END IF;

            IF cc.cod_transaccion = 736 THEN
               v_val_cargo := p_seguro;
            END IF;

            IF cc.obligator = 'S' OR nvl(v_val_cargo, 0) != 0 THEN
               INSERT INTO pr_sol_cargos
                  (nro_solicitud, cod_transaccion, fec_tasa, val_tasa, monto, cod_tasa,
                   cod_ent_seguro, cod_moneda, mto_mon_prestamo)
               VALUES
                  (v_nro_solicitud, v_cod_transaccion, v_fec_inicio, v_val_tas_cargo, v_val_cargo,
                   v_cod_tas_cargo, cc.cod_ent_seguro, v_cod_mon_cargo, NULL);
            END IF;
         END LOOP;
      END;

      -- Calculo de los cargos ----------------------------------------------------
      PROCEDURE pr_act_cargos IS
         ww_dfcargos       NUMBER(18, 2);
         v_mto_equivalente NUMBER(18, 2);
         v_cod_tra_ajuste  NUMBER(4);
         v_monto           NUMBER(18, 2);
         CURSOR cargos IS
            SELECT cod_transaccion,
                   cod_tasa,
                   cod_ent_seguro,
                   val_tasa,
                   monto,
                   cod_moneda,
                   mto_mon_prestamo
              FROM pr_sol_cargos
             WHERE nro_solicitud = v_nro_solicitud
               FOR UPDATE OF monto
             ORDER BY decode(cod_transaccion, 709, 1, 710, 2, cod_transaccion);
      BEGIN
         --- Calculo cada uno de los cargos en la moneda del cargo y en la de la simulacion ---
         --- cero los totales de cargo de tipo valor y el total general de cargos -------------
         v_ttvalor        := 0;
         v_mto_cargo      := 0;
         v_cod_tra_ajuste := NULL;
         FOR cc IN cargos LOOP
            v_mto_equivalente := 0;
            -- para realizar ajustes si es necesario----------
            IF v_cod_tra_ajuste IS NULL THEN
               v_cod_tra_ajuste := cc.cod_transaccion;
            END IF;
            -- obtengo los datos de la tasa-----------------
            pr_obt_tipo_de_tasa(cc.cod_transaccion, cc.cod_tasa, v_aplicar, v_tpvlpor, v_tpdetas);
            IF cc.cod_transaccion IS NOT NULL AND
               (cc.cod_moneda IS NULL OR (v_tpvlpor = 'V' AND nvl(cc.monto, 0) = 0)) THEN
               raise_application_error(-20000,
                                       'Valores nulos en Cargos. Verificar la Trans. ' ||
                                        to_char(cc.cod_transaccion));
            END IF;
            IF v_tpvlpor = 'P' THEN
               v_mto_equivalente := 0;
               --- la tasa es un porcentaje-----------------------------------------------------
               IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
                  --- aplicable al interes -----------------------------------------------------
                  v_mto_equivalente := round(v_mto_interes * /* v_DIA_PLAZO * */
                                             cc.val_tasa / 100, v_redondeo);
               END IF;
               IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
                  --- es aplicable al capital --------------------------------------------------
                  v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                       round(v_tot_prestamo * /*v_DIA_PLAZO **/
                                             cc.val_tasa / 100, v_redondeo);
               END IF;
            ELSIF v_tpvlpor = 'I' THEN
               v_mto_equivalente := 0;
               --- la tasa es un impuesto ------------------------------------------------------
               IF v_aplicar IN ('CI', 'IN', 'PI', 'IP', 'PT', 'TP') THEN
                  --- aplicable al interes -----------------------------------------------------
                  IF v_dia_plazo < 365 THEN
                     v_mto_equivalente := round(v_mto_interes * v_dia_plazo * cc.val_tasa / 36500,
                                                v_redondeo);
                  ELSE
                     v_mto_equivalente := round(v_mto_interes * cc.val_tasa / 100, v_redondeo);
                  END IF;
               END IF;
               IF v_aplicar IN ('CA', 'CI', 'PC', 'CP', 'PT', 'TP') THEN
                  --- es aplicable al capital --------------------------------------------------
                  IF cc.cod_ent_seguro IS NOT NULL THEN
                     --- es un seguro ----------------------------------------------------------
                     v_mto_equivalente := cc.monto;
                  ELSE
                     --- es un impuesto sobre el capital ---------------------------------------
                     IF v_dia_plazo < 365 THEN
                        v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                             round(v_tot_prestamo * v_dia_plazo * cc.val_tasa /
                                                   36500, v_redondeo);
                     ELSE
                        v_mto_equivalente := nvl(v_mto_equivalente, 0) +
                                             round(v_tot_prestamo * cc.val_tasa / 100, v_redondeo);
                     END IF;
                  END IF;
               END IF;
            ELSIF v_tpvlpor = 'V' THEN
               --- es un monto valor -----------------------------------------------------------
               v_mto_equivalente := cc.monto;
               v_ttvalor         := nvl(v_ttvalor, 0) + nvl(v_mto_equivalente, 0);
            END IF;
            --- Acumular el total de cargos (Si el tipo es Valor viene directamente aqui -------
            v_mto_cargo := nvl(v_mto_cargo, 0) + nvl(v_mto_equivalente, 0);
            ------------------------------------------------------------------------------------
            v_monto := NULL;
            IF v_tpvlpor IN ('I', 'P') THEN
               /* solo si es porcentaje */
               IF cc.cod_moneda = p_cod_moneda THEN
                  -- moneda del cargo es igual a la moneda de la simulacion ----------------------
                  v_monto := v_mto_equivalente;
               ELSE
                  -- monedas diferentes, se divide por la cotiz. de la moneda de la simulacion ---
                  v_monto := round(v_mto_equivalente * v_cotizacion, v_redondeo);
               END IF;
            END IF;
            UPDATE pr_sol_cargos
               SET mto_mon_prestamo = nvl(v_mto_equivalente, 0),
                   monto            = nvl(v_monto, monto)
             WHERE CURRENT OF cargos;
         END LOOP;
         IF v_mto_cargo >= v_tot_prestamo THEN
            raise_application_error(-20000,
                                    'ERROR. Total de Cargos ' || v_mto_cargo ||
                                     ' es superior al Total del Prestamo ' || v_tot_prestamo);
         ELSE
            IF v_tip_monto = 'N' AND v_tot_prestamo <> p_monto THEN
               --- ya estoy en el ultimo calculo de cargos netos, veo si hay ajuste --------
               IF nvl(v_tot_prestamo, 0) - nvl(v_mto_cargo, 0) <> p_monto THEN
                  -- es necesario un ajuste en el cargo del impuesto o primer cargo      ---
                  ww_dfcargos := p_monto - (nvl(v_tot_prestamo, 0) - nvl(v_mto_cargo, 0));
                  --V_MTO_EQUIVALENTE := NVL(V_MTO_EQUIVALENTE, 0) - ww_dfcargos;
                  v_mto_cargo := nvl(v_mto_cargo, 0) - ww_dfcargos;
                  UPDATE pr_sol_cargos
                     SET mto_mon_prestamo = nvl(mto_mon_prestamo, 0) - nvl(ww_dfcargos, 0),
                         monto            = decode(cod_moneda, p_cod_moneda,
                                                   nvl(mto_mon_prestamo, 0) - nvl(ww_dfcargos, 0),
                                                   decode(cod_moneda, v_mon_local,
                                                           round(((nvl(mto_mon_prestamo, 0) -
                                                                  nvl(ww_dfcargos, 0)) * v_cotizacion),
                                                                  v_redondeo),
                                                           round(((nvl(mto_mon_prestamo, 0) -
                                                                  nvl(ww_dfcargos, 0)) * v_cotizacion),
                                                                  v_redondeo)))
                   WHERE nro_solicitud = v_nro_solicitud
                     AND cod_transaccion = v_cod_tra_ajuste;
               END IF;
            END IF;
         END IF;
         -- actualizo el total de cargos de  la solicitud
         UPDATE pr_solicitudes SET mto_cargo = v_mto_cargo WHERE nro_solicitud = v_nro_solicitud;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'CALCULAR_CARGOS ' || SQLERRM);
      END;
      -- INICIO DEL PROCEDIMIENTO PRINCIPAL----------------------------------------
   BEGIN

      ---Busco sector de credito
      SELECT referencia
        INTO v_cod_sec_credito
        FROM pr_rub_economicos
       WHERE cod_rub_economico = p_cod_rub_economico;

      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, p_cod_modalidad, p_cod_moneda);
      -- Valido el codigo del cliente-------------------------------------------
      pr_val_cod_persona;
      -- Valido el codigo de la modalidad que recibo----------------------------
      pr_val_cod_modalidad;
      -- valido la moneda-------------------------------------------------------
      pr_val_cod_moneda;
      -- valido el monto -------------------------------------------------------
      IF nvl(p_monto, 0) <= 0 THEN
         raise_application_error(-20000, 'ERROR. Ingrese Monto del Credito');
      END IF;
      v_tot_prestamo := p_monto;
      -- valido el tipo de monto -----------------------------------------------
      IF nvl(v_tip_monto, 'X') NOT IN ('B', 'N') THEN
         raise_application_error(-20000, 'ERROR. Tipo de Monto debe ser B-Bruto o N-Neto');
      END IF;
      -- valido la cantidad de cuotas ------------------------------------------
      IF nvl(p_can_cuotas, 0) < 1 THEN
         raise_application_error(-20000, 'ERROR. Ingrese la cantidad de cuotas');
      END IF;

      IF nvl(fug_obt_parentes(v_cod_ente, 'CRM_COM_CAR_MOROSA') , 'N') = 'N' THEN
         -- Valido la fecha del primer vencimiento --------------------------------
         IF v_fec_pri_vencimiento <= v_fec_actual AND p_cod_modalidad <> 65 THEN
            raise_application_error(-20000,
                                 'ERROR. Primer Vencimiento 1 debe ser posterior a la fecha de Hoy');
         END IF;
         v_dia_plazo   := add_months(v_fec_pri_vencimiento, p_can_cuotas - 1) - v_fec_inicio;
         v_per_gracia  := v_fec_pri_vencimiento - v_fec_inicio;
         v_per_capital := 30;
         v_fec_inicio2 := v_fec_inicio;
      ELSE
         v_dia_plazo   := add_months(v_fec_pri_vencimiento, p_can_cuotas - 1) - v_fec_ini_operacion;
         v_per_gracia  := v_fec_pri_vencimiento - v_fec_ini_operacion;
         v_per_capital := 30;
         v_fec_inicio2 := v_fec_ini_operacion;
      END IF;

      -- Valido la tasa de interes ---------------------------------------------
      pr_val_tasa;
      -- Asigno el nro de la solicitud -----------------------------------------
      IF v_grabar = 'S' THEN
         SELECT s_nro_sol_prestamos.nextval INTO v_nro_solicitud FROM dual;
      ELSE
         --- Recupero secuencia negativa para solicitud auxiliar
         SELECT s_nro_sol_negativo.nextval INTO v_nro_solicitud FROM dual;
      END IF;
      ---- Origen de Fondos
      IF p_cod_moneda IS NOT NULL AND p_cod_modalidad IS NOT NULL THEN
         v_ori_fondo := nvl(fup_obt_ori_fon_modalidad(p_cod_modalidad, p_cod_moneda), 0);
      END IF;

      IF v_ori_fondo = 0 THEN
         v_ori_fondo := fug_obt_pardinamico('COD_ORI_FON_DESEMB', v_cod_modulo, p_cod_modalidad,
                                            p_cod_moneda, v_cod_oficina);
      END IF;
      v_tipo := p_tip_ptmo;
      -- inserto el registro en la tabla de solicitudes ------------------------
      INSERT INTO pr_solicitudes
         (nro_solicitud, descripcion, monto, tip_interes, tip_amortizacion, dia_plazo,
          fec_vencimiento, mto_interes, per_vto_capital, per_gracia, cod_persona, fec_inicio,
          tip_monto, tot_prestamo, cod_modulo, cod_modalidad, cod_moneda, cod_oficina,
          fec_pri_vencimiento, cod_sec_credito, cod_rub_economico, cod_departamento, tip_documento,
          exo_impuesto, cod_usu_promotor, cod_canal, cod_campana, tip_destino, cod_banca,
          tip_renovacion, cod_ori_fondo, por_ori_fondo, tipo, tip_aju_fecha, aju_gracia,
          est_verificacion, aut_pendiente, estado, cod_sub_modalidad)
      VALUES
         (v_nro_solicitud, nvl(p_descripcion, '.'), p_monto, v_tip_interes, v_tip_amortizacion,
          /* price */ v_dia_plazo, v_fec_vencimiento, v_mto_interes, v_per_capital, v_per_gracia,
          p_cod_persona, v_fec_inicio2, v_tip_monto, v_tot_prestamo, v_cod_modulo, p_cod_modalidad,
          p_cod_moneda, v_cod_oficina, v_fec_pri_vencimiento, v_cod_sec_credito, p_cod_rub_economico,
          nvl(v_cod_departamento, v_cod_dep_parametro), v_tip_documento /* vista*/, v_exo_impuestos,
          nvl(p_cod_usu_promotor, v_cod_usu_promotor), p_cod_canal, p_cod_campana, p_tip_destino,
          p_cod_banca, v_tip_renovacion, v_ori_fondo, 100, v_tipo, v_tip_aju_fecha, v_aju_gracia,
          'N', 'N', 'S', 1);
      --Inserta el destino Especifico
      pr_ins_pr_sol_destinos(v_nro_solicitud, p_monto);


      --Inserta la tasa de la solicitud
      pr_ins_pr_sol_tas_ven(v_nro_solicitud, v_val_tasa, v_per_capital);



       -- Inserto las cuotas
      pr_ins_pr_sol_cuo_ven(v_nro_solicitud,
                            p_monto,
                            v_val_tasa,
                            v_mto_interes,
                            p_can_cuotas,
                            v_car_calculado,
                            p_cod_modalidad,
                            p_cod_moneda);

       --Inserta la Garantia
      pr_ins_pr_sol_garantias(v_nro_solicitud, p_monto - nvl(v_mto_interes,0));

      -- Genero los cargos por defecto
      pr_ins_sol_cargos(v_car_calculado);

      -- Calculo los cargos ----------------------------------------------------
      pr_act_cargos;

      --Obtener la fecha del último vencimiento
     begin
         select max(fec_vto_habil)
           into v_fec_vencimiento
           from pr_sol_cuotas
          where nro_solicitud = v_nro_solicitud;
      end;

      -- verifico el tipo de prestamo
      IF v_tip_monto = 'B' THEN
         v_tot_prestamo := p_monto;
         UPDATE pr_solicitudes
            SET monto           = monto - NVL(v_mto_interes,0),
                tot_prestamo    = v_tot_prestamo - NVL(v_mto_interes,0),
                tot_desembolsar = nvl(v_tot_prestamo, 0) - NVL(v_mto_interes,0) -
                                  nvl(v_mto_cargo, 0),
                mto_interes     = v_mto_interes,
                can_desembolsos = 1,
                fec_vencimiento = v_fec_vencimiento,
                dia_plazo       = v_fec_vencimiento - fec_inicio
          WHERE nro_solicitud = v_nro_solicitud;

          update pr_sol_destinos d
          set d.monto = v_tot_prestamo - NVL(v_mto_interes,0)
          where nro_solicitud = v_nro_solicitud;

      END IF;
      p_nro_solicitud := v_nro_solicitud;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'Propuesta ' || SQLERRM);
         END IF;
   END;

 -- Procedimiento que Inserta las Cuotas de la Solicitud.
   PROCEDURE pr_ins_pr_sol_cuo_ven
   (
      p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
      p_monto         IN pr_solicitudes.monto%TYPE,
      p_val_tasa      IN pr_sol_tasas.val_tasa%TYPE,
      p_mto_interes   OUT pr_solicitudes.mto_interes%TYPE,
      p_can_cuotas    IN number,
      p_car_calculado OUT number,
      p_cod_modalidad       IN NUMBER, -- tipo de credito
      p_cod_moneda          IN VARCHAR2 -- moneda
   ) IS

      v_val_interes        pr_sol_cuotas.val_interes%TYPE := 0;
      v_val_int_adelantado pr_sol_cuotas.val_int_adelantado%TYPE := 0;
      v_sal_cap_anterior   pr_sol_cuotas.sal_cap_anterior%TYPE := 0;
      v_nro_cuota          pr_sol_cuotas.nro_cuota%TYPE := 0;
      v_cuo_plazo          NUMBER(10) := 0;
      v_xplazo             number;
      v_xfec_vencimiento   date;
      v_xcap_inicial       number;
      v_redondeo           number;
      v_xint_inicial       number;
      v_xsal_int_inicial   number;
      v_xsal_cap_inicial   number;
      v_xsal_cuota         number;
      v_xsal_capital       number;
      v_fec_vto_anterior   date;
      v_sal_int_inicial    number;
      v_sal_cap_inicial    number;
      v_tot_capital        number;
      v_tot_interes        number;
      v_ult_capital        number;
      v_tot_prestamo       number;
      v_acumula            number:= 0.01;
      v_sale               varchar2(1) := 'N';
      v_xsal_cap_final     number;
      V_NRO_secuencia      NUMBER := 0;
      v_cap_acumulado      number;
      v_int_acumulado      number;
      v_mto_cuota          number;
      v_salir              varchar2(1) := 'N';
       v_final              varchar2(1) := 'N';

   BEGIN
       v_nro_cuota := 0;
       v_val_interes:= 0;
       v_xsal_capital := 0;
       v_tot_interes := 0;
       v_ult_capital:= 0;
       v_tot_capital :=0;
       v_xsal_cap_final:= NULL;

      BEGIN
         DELETE FROM pr_sol_cuotas WHERE nro_solicitud = p_nro_solicitud;


         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, p_cod_modalidad, p_cod_moneda);
         p_mto_interes := 0;
         --Calcular el capital inicial

         begin
           select max(fec_vencimiento)
             into v_xfec_vencimiento
             from pr_cuo_com_cartera
            where cod_ente = v_cod_entidad
              and nro_operacion = v_nro_operacion;
         end;
       IF  v_nro_operacion = 2 THEN
         NULL;
       END IF;

         v_xplazo:= v_xfec_vencimiento - v_fec_inicio;
         v_sal_int_inicial:= round((p_monto * p_val_tasa * v_xplazo)/36500,v_redondeo);
         v_sal_cap_inicial:= p_monto/* - v_sal_int_inicial*/;
         v_fec_vto_anterior:= v_fec_inicio;
         v_xsal_cap_inicial := v_sal_cap_inicial;
         v_tot_prestamo := /*v_sal_int_inicial + */ v_sal_cap_inicial;

     while abs(nvl(v_xsal_cap_final,v_xsal_cap_inicial)) <> 0 and v_final = 'N' LOOP
         DELETE FROM pr_sol_cuotas WHERE nro_solicitud = p_nro_solicitud;
         v_int_acumulado:= 0;
         p_mto_interes := 0;
         v_salir := 'N';
       IF  v_nro_operacion = 2 THEN
         NULL;
       END IF;
         FOR rcuo IN cuo_ctas(v_cod_entidad, v_nro_operacion) LOOP
            IF rcuo.fec_vencimiento > v_fec_inicio OR
               nvl(fug_obt_parentes(v_cod_ente, 'CRM_COM_CAR_MOROSA') , 'N') = 'S' THEN
               v_nro_cuota := v_nro_cuota + 1;

               v_cuo_plazo := rcuo.fec_vencimiento - v_fec_vto_anterior;
               v_fec_vto_anterior:= rcuo.fec_vencimiento;
                 -- v_val_int_adelantado := rcuo.sal_interes;
                 -- v_val_interes        := v_val_interes + v_val_int_adelantado;
               v_val_interes:= round(v_xsal_cap_inicial * p_val_tasa * v_cuo_plazo/36500,v_redondeo);

               v_xsal_capital := rcuo.mto_cuota - v_val_interes;

               if v_xsal_capital < 0 and v_nro_cuota <> p_can_cuotas then
                  v_int_acumulado:= nvl(v_int_acumulado,0) + abs(v_xsal_capital);
                  v_xsal_capital:=0;
                  v_val_interes := rcuo.mto_cuota;
               end if;

               if v_nro_cuota <> p_can_cuotas then
                  v_xsal_cap_inicial := v_xsal_cap_inicial - v_xsal_capital;
               end if;

           v_tot_interes := nvl(v_tot_interes,0) + v_val_interes;
           IF v_xsal_cap_inicial > 0 then
               if v_nro_cuota = p_can_cuotas then
                  if (nvl(v_tot_capital,0) + nvl(v_tot_interes,0)) < v_tot_prestamo then
                    v_ult_capital := nvl(v_tot_prestamo,0) - (v_tot_capital + v_tot_interes);
                    v_xsal_capital := v_ult_capital;
                    v_xsal_cap_inicial := v_xsal_cap_inicial - v_xsal_capital - v_tot_interes;
                  end if;
               else
                  --v_tot_interes := nvl(v_tot_interes,0) + v_val_interes;
                  v_tot_capital := nvl(v_tot_capital,0) + v_xsal_capital;
               end if;

             IF  v_nro_cuota = p_can_cuotas THEN
               if ABS(v_xsal_cap_inicial)< 0.50 then
                    v_val_interes:=v_val_interes-v_xsal_cap_inicial;
                    v_tot_interes:=v_tot_interes-v_xsal_cap_inicial;
                    if (nvl(v_tot_capital,0) + nvl(v_tot_interes,0)) < v_tot_prestamo then
                       v_ult_capital := nvl(v_tot_prestamo,0) - (v_tot_capital + v_tot_interes);
                       v_xsal_capital := v_ult_capital;
                  end if;
               v_final := 'S';
               end if;
              END IF;
               if v_nro_cuota = p_can_cuotas then
                  v_mto_cuota := round(v_val_interes + v_xsal_capital,v_redondeo);
               else
                  v_mto_cuota := rcuo.mto_cuota;
               end if;

               IF v_nro_cuota = 1 THEN
                  v_sal_cap_anterior := p_monto;
               ELSE
                  v_sal_cap_anterior := v_sal_cap_anterior - v_mto_cuota;
               END IF;

               /* INSERT INTO pr_cuo_com_cartera_tmp(nro_solicitud,nro_cuota,mto_capital,fec_vto_habil,
                        fec_vto_exacto,val_interes,sal_capital,sal_cap_anterior,dia_periodo,dia_interes,val_int_original)
                     VALUES(p_nro_solicitud, v_nro_cuota, v_xsal_capital, rcuo.fec_vencimiento,
                       rcuo.fec_vencimiento, v_val_interes, 0, v_sal_cap_anterior, v_cuo_plazo, v_cuo_plazo,0) ;
*/

               INSERT INTO pr_sol_cuotas
                  (nro_solicitud, nro_cuota, mto_capital, fec_vto_habil, fec_vto_exacto,
                   val_interes, sal_capital, sal_cap_anterior, dia_periodo, dia_interes,
                   val_int_original)
                VALUES
                  (p_nro_solicitud, v_nro_cuota, v_xsal_capital, rcuo.fec_vencimiento,
                   rcuo.fec_vencimiento, abs(v_val_interes), 0, abs(v_sal_cap_anterior), v_cuo_plazo, v_cuo_plazo,
                  0);
            else
               v_salir := 'S';
               EXIT WHEN v_salir = 'S';
            end if;

            ELSE
               v_con_error := 'S';

               pr_ins_log(0,
                          'La Fecha de la Cuota Debe ser Mayor a la Fecha del Proceso. ' ||
                           rcuo.fec_vencimiento || ' - ' || v_fec_inicio,
                          v_com_error || ', PR_INS_PR_DOCUMENTOS', v_fec_actual, v_cod_ente);
            END IF;

              v_val_interes:=0;
              v_xsal_capital:=0;
              v_cuo_plazo:= 0;
         END LOOP;
          p_mto_interes := v_tot_interes;

         if abs(nvl(v_xsal_cap_final,v_xsal_cap_inicial)) <> 0 OR v_salir = 'S' then

            v_xsal_cap_final:= ROUND(v_xsal_cap_inicial,V_REDONDEO);
            v_xsal_cap_inicial:=  nvl(v_sal_cap_inicial,0)  - v_xsal_cap_inicial;
            v_sal_cap_inicial:= v_xsal_cap_inicial;

            --inicializar todas las variables
            v_nro_cuota := 0;
            v_val_interes:= 0;
            v_xsal_capital := 0;
            v_tot_interes := 0;
            v_ult_capital:= 0;
            v_tot_capital :=0;
            v_fec_vto_anterior:= v_fec_inicio;
         end if;
          v_nro_cuota := 0;
          p_car_calculado:= v_int_acumulado;
          v_nro_secuencia := NVL(v_nro_secuencia,0) + 1;
         END LOOP;

         INSERT INTO pr_sol_cuotas
            (nro_solicitud, nro_cuota, mto_capital, fec_vto_habil, fec_vto_exacto, val_interes,
             sal_capital, sal_cap_anterior, dia_periodo, dia_interes, val_int_original,
             val_int_adelantado)
         VALUES
            (p_nro_solicitud, 0, 0, v_fec_inicio, v_fec_inicio, v_val_interes, p_monto, 0, 0, 0, 0,
             0);

      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';

            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_CUOTAS',
                       v_fec_actual, v_cod_ente);
      END;
   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';

         pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_CUOTAS',
                    v_fec_actual, v_cod_ente);
   END;
   -- Procedimiento que Inserta las Tasas de la Solicitud.
   PROCEDURE pr_ins_pr_sol_tas_ven
   (
      p_nro_solicitud   IN pr_solicitudes.nro_solicitud%TYPE,
      p_val_tasa        IN pr_sol_tasas.val_tasa%TYPE,
      p_per_vencimiento IN pr_sol_tasas.per_vencimiento%TYPE
   ) IS
     v_fec_inicio2  DATE;
   BEGIN
      IF nvl(fug_obt_parentes(v_cod_ente, 'CRM_COM_CAR_MOROSA') , 'N') = 'N' THEN
         v_fec_inicio2 := v_fec_inicio;
      ELSE
         v_fec_inicio2 := v_fec_ini_operacion;
      END IF;

      BEGIN
         INSERT INTO pr_sol_tasas
            (nro_solicitud, fec_vigencia, val_tasa, tip_cobro, per_vencimiento)
         VALUES
            (p_nro_solicitud, v_fec_inicio2, p_val_tasa, 'V', p_per_vencimiento);

      EXCEPTION
         WHEN OTHERS THEN
            v_con_error := 'S';

            pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_TASAS',
                       v_fec_actual, v_cod_ente);
      END;

   EXCEPTION
      WHEN OTHERS THEN
         v_con_error := 'S';

         pr_ins_log(SQLCODE, substr(SQLERRM, 1, 500), v_com_error || ', PR_INS_PR_SOL_TASAS',
                    v_fec_actual, v_cod_ente);
   END;

Procedure pr_pro_persona(p_Tipo In Varchar2 Default Null) Is
    v_Nom_Completo Ba_Personas.Nom_Completo%Type := Null;
    v_Existe       Varchar2(1);

    /*Actualizar conyuge*/
    Procedure Lp_Act_Conyuge(p_Cod_Persona  In Ba_Personas.Cod_Persona%Type,
                             p_Cod_Per_Cony In Ba_Personas.Cod_Persona%Type) Is
      v_Cod_Per_Conyuge Ba_Personas.Cod_Persona%Type := Null;
    Begin
      Begin
        Select Cod_Per_Vinculo
          Into v_Cod_Per_Conyuge
          From Ba_Vinculos
         Where Cod_Persona = p_Cod_Persona
           And Tipo = 'E';
      Exception
        When Others Then
          v_Cod_Per_Conyuge := Null;
      End;
      If v_Cod_Per_Conyuge Is Null Then
        Insert Into Ba_Vinculos
          (Cod_Persona, Cod_Per_Vinculo, Tipo, Estado)
        Values
          (p_Cod_Persona, p_Cod_Per_Cony, 'E', 'A');
      Else
        If v_Cod_Per_Conyuge <> p_Cod_Per_Cony Then
          v_Con_Error := 'S';
          Pr_Ins_Log(0,
                     'ERROR AL ACTUALIZAR VINCULOS. Persona' ||
                     p_Cod_Persona ||
                     ' posee vinculo de esposo/a con otra persona - ' ||
                     Sqlerrm,
                     v_Com_Error || ', PR_PRO_COMPRA',
                     v_Fec_Actual,
                     v_Cod_Ente);
        End If;
      End If;
    Exception
      When Others Then
        If Sqlcode <= -20000 Then
          Raise;
        Else
          Raise_Application_Error(-20000, 'Act.Conyuge ' || Sqlerrm);
        End If;
    End;

  Begin
    v_Con_Error := 'N';

    Begin
      Pre_Ini_Aplicacion;
      Pae_Cnf.g_Cod_Modulo := 1;
    End;

    For Rctas In Ctas Loop
      v_Cod_Oficina       := Rctas.Cod_Oficina;
      v_Cod_Moneda        := Rctas.Cod_Moneda;
      v_Nro_Operacion     := Rctas.Nro_Operacion;
      v_Nom_Completo      := Rctas.Nombre || ' ' || Rctas.Apellido;
      v_Cod_Oficial       := Rctas.Cod_Usu_Oficial;
      v_Cod_Ente          := Rctas.Cod_Ente;
      v_Cod_Pais          := Rctas.Cod_Pais;
      v_Fec_Ini_Operacion := Rctas.Fec_Ini_Operacion;
      v_Cod_Rub_Economico := Rctas.Cod_Rub_Primario;

      ---Inserta Persona
      Pr_Ins_Personas(Rctas.Nro_Documento,
                      Rctas.Cod_Tip_Documento,
                      Rctas.Cod_Pais,
                      Rctas.Nombre,
                      Rctas.Apellido,
                      Rctas.Tipo,
                      Rctas.Fec_Nacimiento,
                      Rctas.Cod_Rub_Primario,
                      v_Cod_Persona,
                      Rctas.Cod_Sex_Cliente);
      ---Inserta Conyuge
      If Rctas.Nro_Doc_Conyuge Is Not Null Then
        Pr_Ins_Personas(Rctas.Nro_Doc_Conyuge,
                        Rctas.Cod_Tip_Doc_Conyuge,
                        Rctas.Cod_Pais,
                        Rctas.Nom_Conyuge,
                        Rctas.Ape_Conyuge,
                        'F',
                        Null,
                        Rctas.Cod_Rub_Primario,
                        v_Cod_Per_Cony,
                        Rctas.Cod_Sex_Conyuge);
        Lp_Act_Conyuge(v_Cod_Persona, v_Cod_Per_Cony);
      End If;
      ---Inserta Codeudor
      If Rctas.Nro_Doc_Codeudor Is Not Null Then
        Pr_Ins_Personas(Rctas.Nro_Doc_Codeudor,
                        Rctas.Cod_Tip_Doc_Codeudor,
                        Rctas.Cod_Pais,
                        Rctas.Nom_Codeudor,
                        Rctas.Ape_Codeudor,
                        'F',
                        Null,
                        Rctas.Cod_Rub_Primario,
                        v_Cod_Per_Codeu,
                        Rctas.Cod_Sex_Codeudor);
      End If;
      ---Inserta Conyuge del Codeudor
      If Rctas.Nro_Doc_Cony_Codeudor Is Not Null Then
        Pr_Ins_Personas(Rctas.Nro_Doc_Cony_Codeudor,
                        Rctas.Cod_Tip_Doc_Cony_Codeudor,
                        Rctas.Cod_Pais,
                        Rctas.Nom_Cony_Codeudor,
                        Rctas.Ape_Cony_Codeudor,
                        'F',
                        Null,
                        Rctas.Cod_Rub_Primario,
                        v_Cod_Per_Cony_Codeu,
                        Rctas.Cod_Sex_Cony_Codeudor);
        Lp_Act_Conyuge(v_Cod_Per_Codeu, v_Cod_Per_Cony_Codeu);
      End If;

      ---Inserta Direcciones
      Pr_Ins_Dir_Personas(Rctas.Dir_Particular,
                          Rctas.Dir_Laboral,
                          Rctas.Cod_Pais_Dir_Particular,
                          Rctas.Cod_Pais_Dir_Laboral,
                          Rctas.Cod_Ciu_Dir_Particular,
                          Rctas.Cod_Ciu_Dir_Laboral,
                          Rctas.Cod_Bar_Dir_Particular,
                          Rctas.Cod_Bar_Dir_Laboral,
                          Rctas.Nro_Dir_Particular,
                          Rctas.Nro_Dir_Laboral,
                          Rctas.Obs_Dir_Particular,
                          Rctas.Obs_Dir_Laboral);
      ---Inserta Telefonos
      Pr_Ins_Tel_Personas(Rctas.Tel_Particular,
                          Rctas.Tel_Laboral,
                          Rctas.Area_Tel_Particular,
                          Rctas.Area_Tel_Laboral,
                          Rctas.Tip_Linea_Particular,
                          Rctas.Tip_Linea_Laboral);

      If Rctas.Tipo = 'F' Then
        ---Inserta Informacion Laboral
        Pr_Ins_Cr_Inf_Laboral(Rctas.Lug_Trabajo,
                              Rctas.Mto_Ingreso,
                              Rctas.Des_Puesto,
                              Rctas.Antiguedad);
      End If;
      ---Inserta Cliente
      Pr_Ins_Ge_Cliente(Null, v_Cod_Oficina, Null);

      If v_Con_Error = 'S' Then

        Pr_Ins_Log(0,
                   'ALTA NO PROCESADA: ' || Rctas.Nro_Documento,
                   v_Com_Error || ', PR_PRO_COMPRA',
                   v_Fec_Actual,
                   v_Cod_Ente);

      End If;
      Commit;
    End Loop;

  End;
END pap_com;
/
