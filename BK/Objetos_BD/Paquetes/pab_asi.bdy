CREATE OR REPLACE PACKAGE BODY IT.PAB_ASI IS

   -- funcion que retorna la lista de valores
   FUNCTION fu_lis_sit_contable RETURN tyb_tab_sit_contable
      PIPELINED IS
      -- define la salida en formato tabla
      reg tyb_col_sit_contable := tyb_col_sit_contable(NULL, NULL);
   BEGIN
      -- Registro de codigos y descripciones
      --CCI
      --reg.CODIGO := 81000001; reg.DESCRIPCION := 'CCI-Stand by-Con Corresp.-ALADI-Doméstica';  PIPE ROW(reg);
      --reg.CODIGO := 81000002; reg.DESCRIPCION := 'CCI-Stand by-Con Corresp.-ALADI-NO Doméstica'; PIPE ROW(reg);
      --reg.CODIGO := 81000003; reg.DESCRIPCION := 'CCI-Stand by-Con Corresp.-NO ALADI-Doméstica'; PIPE ROW(reg);
      reg.codigo      := 81000004;
      reg.descripcion := 'CCI-Stand by-Con Corresp.-NO ALADI-NO Doméstica';
      PIPE ROW(reg);

      --reg.CODIGO := 81000005; reg.DESCRIPCION := 'CCI-Stand by-Sin Corresp.-ALADI-Doméstica';  PIPE ROW(reg);
      --reg.CODIGO := 81000006; reg.DESCRIPCION := 'CCI-Stand by-Sin Corresp.-ALADI-NO Doméstica'; PIPE ROW(reg);
      --reg.CODIGO := 81000007; reg.DESCRIPCION := 'CCI-Stand by-Sin Corresp.-NO ALADI-Doméstica'; PIPE ROW(reg);
      --reg.CODIGO := 81000008; reg.DESCRIPCION := 'CCI-Stand by-Sin Corresp.-NO ALADI-NO Doméstica'; PIPE ROW(reg);

      --reg.CODIGO := 81000009; reg.DESCRIPCION := 'CCI-NO Stand by-Con Corresp.-ALADI-Doméstica';  PIPE ROW(reg);
      reg.codigo      := 81000010;
      reg.descripcion := 'CCI-NO Stand by-Con Corresp.-ALADI-NO Doméstica';
      PIPE ROW(reg);
      reg.codigo      := 81000011;
      reg.descripcion := 'CCI-NO Stand by-Con Corresp.-NO ALADI-Doméstica';
      PIPE ROW(reg);
      reg.codigo      := 81000012;
      reg.descripcion := 'CCI-NO Stand by-Con Corresp.-NO ALADI-NO Doméstica';
      PIPE ROW(reg);

      --reg.CODIGO := 81000013; reg.DESCRIPCION := 'CCI-NO Stand by-Sin Corresp.-ALADI-Doméstica';  PIPE ROW(reg);
      --reg.CODIGO := 81000014; reg.DESCRIPCION := 'CCI-NO Stand by-Sin Corresp.-ALADI-NO Doméstica'; PIPE ROW(reg);
      reg.codigo      := 81000015;
      reg.descripcion := 'CCI-NO Stand by-Sin Corresp.-NO ALADI-Doméstica';
      PIPE ROW(reg);
      --reg.CODIGO := 81000016; reg.DESCRIPCION := 'CCI-NO Stand by-Sin Corresp.-NO ALADI-NO Doméstica'; PIPE ROW(reg);

      --CCE
      --reg.CODIGO := 82000001; reg.DESCRIPCION := 'CCE-Confirmada-Con Corresp.-ALADI-Doméstica';  PIPE ROW(reg);
      reg.codigo      := 82000002;
      reg.descripcion := 'CCE-Confirmada-Con Corresp.-ALADI-NO Doméstica';
      PIPE ROW(reg);
      reg.codigo      := 82000003;
      reg.descripcion := 'CCE-Confirmada-Con Corresp.-NO ALADI-Doméstica';
      PIPE ROW(reg);
      reg.codigo      := 82000004;
      reg.descripcion := 'CCE-Confirmada-Con Corresp.-NO ALADI-NO Doméstica';
      PIPE ROW(reg);

      --reg.CODIGO := 82000005; reg.DESCRIPCION := 'CCE-Confirmada-Sin Corresp.-ALADI-Doméstica';  PIPE ROW(reg);
      --reg.CODIGO := 82000006; reg.DESCRIPCION := 'CCE-Confirmada-Sin Corresp.-ALADI-NO Doméstica'; PIPE ROW(reg);
      reg.codigo      := 82000007;
      reg.descripcion := 'CCE-Confirmada-Sin Corresp.-NO ALADI-Doméstica';
      PIPE ROW(reg);
      --reg.CODIGO := 82000008; reg.DESCRIPCION := 'CCE-Confirmada-Sin Corresp.-NO ALADI-NO Doméstica'; PIPE ROW(reg);

      --reg.CODIGO := 82000009; reg.DESCRIPCION := 'CCE-NO Confirmada-Con Corresp.-ALADI-Doméstica';  PIPE ROW(reg);
      reg.codigo      := 82000010;
      reg.descripcion := 'CCE-NO Confirmada-Con Corresp.-ALADI-NO Doméstica';
      PIPE ROW(reg);
      reg.codigo      := 82000011;
      reg.descripcion := 'CCE-NO Confirmada-Con Corresp.-NO ALADI-Doméstica';
      PIPE ROW(reg);
      reg.codigo      := 82000012;
      reg.descripcion := 'CCE-NO Confirmada-Con Corresp.-NO ALADI-NO Doméstica';
      PIPE ROW(reg);

      --reg.CODIGO := 82000013; reg.DESCRIPCION := 'CCE-NO Confirmada-Sin Corresp.-ALADI-Doméstica';  PIPE ROW(reg);
      --reg.CODIGO := 82000014; reg.DESCRIPCION := 'CCE-NO Confirmada-Sin Corresp.-ALADI-Doméstica'; PIPE ROW(reg);
      reg.codigo      := 82000015;
      reg.descripcion := 'CCE-NO Confirmada-Sin Corresp.-NO ALADI-Doméstica';
      PIPE ROW(reg);
      --reg.CODIGO := 82000016; reg.DESCRIPCION := 'CCE-NO Confirmada-Sin Corresp.-NO ALADI-NO Doméstica'; PIPE ROW(reg);

      --Cobranzas
      --reg.CODIGO := 83000001; reg.DESCRIPCION := 'COBRANZA-Avalada-Con Corresp.-Doméstica';  PIPE ROW(reg);
      reg.codigo      := 83000002;
      reg.descripcion := 'COBRANZA-Avalada-Con Corresp.-NO Doméstica';
      PIPE ROW(reg);
      --reg.CODIGO := 83000003; reg.DESCRIPCION := 'COBRANZA-Avalada-Sin Corresp.-Doméstica'; PIPE ROW(reg);
      --reg.CODIGO := 83000004; reg.DESCRIPCION := 'COBRANZA-Avalada-Sin Corresp.-NO Doméstica'; PIPE ROW(reg);

      --reg.CODIGO := 83000005; reg.DESCRIPCION := 'COBRANZA-NO Avalada-Con Corresp.-Doméstica';  PIPE ROW(reg);
      reg.codigo      := 83000006;
      reg.descripcion := 'COBRANZA-NO Avalada-Con Corresp.-NO Doméstica';
      PIPE ROW(reg);
      --reg.CODIGO := 83000007; reg.DESCRIPCION := 'COBRANZA-NO Avalada-Sin Corresp.-Doméstica'; PIPE ROW(reg);
      --reg.CODIGO := 83000008; reg.DESCRIPCION := 'COBRANZA-NO Avalada-Sin Corresp.-NO Doméstica'; PIPE ROW(reg);

      --Fianzas
      reg.codigo      := 88000001;
      reg.descripcion := 'FIANZA-Stand by-Con Contragarantía';
      PIPE ROW(reg);
      reg.codigo      := 88000002;
      reg.descripcion := 'FIANZA-Stand by-Sin Contragarantía';
      PIPE ROW(reg);
      reg.codigo      := 88000003;
      reg.descripcion := 'FIANZA-NO Stand by-Con Contragarantía';
      PIPE ROW(reg);
      reg.codigo      := 88000004;
      reg.descripcion := 'FIANZA-NO Stand by-Sin Contragarantía';
      PIPE ROW(reg);

      --Venta/Cobro de Documentos
      reg.codigo      := 10000000;
      reg.descripcion := 'Normal';
      PIPE ROW(reg);
      reg.codigo      := 10000001;
      reg.descripcion := 'Venta Doc. RE-COMPRA';
      PIPE ROW(reg);
      reg.codigo      := 10000002;
      reg.descripcion := 'Compra Doc. RE-VENTA';
      PIPE ROW(reg);
      reg.codigo      := 10000003;
      reg.descripcion := 'Reclasificacion REPO';
      PIPE ROW(reg);

      RETURN;
   END fu_lis_sit_contable;

   -- funcion que retorna un numero calculado que identifica la situacion contable actual de la operacion
   FUNCTION fu_cal_sit_contable(p_nro_cuenta IN VARCHAR2) RETURN NUMBER IS

      v_sit_contable NUMBER(20);
      --
      v_cod_modulo      NUMBER(5);
      v_cod_modalidad   NUMBER(5);
      v_cod_oficina     NUMBER(5);
      v_cod_moneda      VARCHAR2(4);
      v_estado          VARCHAR2(1);
      v_fec_apertura    DATE;
      v_fec_vencimiento DATE;
      -- comercio exterior
      v_con_aladi          VARCHAR2(1);
      v_confirmado         VARCHAR2(1);
      v_con_corresponsal   VARCHAR2(1);
      v_ubi_bco_negociador VARCHAR2(1);
      v_stand_by           VARCHAR2(1);
      v_avalada            VARCHAR2(1);
      v_contragarantia     VARCHAR2(1);
      -- Variable Mesa de Dinero
      v_cod_mod_mesa   md_cta_documentos.cod_modalidad%TYPE;
      --
   BEGIN
      -- busco los datos básicos de la cuenta
      SELECT cod_modulo,
             cod_modalidad,
             cod_oficina,
             cod_moneda,
             estado,
             fec_apertura,
             fec_vencimiento
        INTO v_cod_modulo,
             v_cod_modalidad,
             v_cod_oficina,
             v_cod_moneda,
             v_estado,
             v_fec_apertura,
             v_fec_vencimiento
        FROM ge_cuentas
       WHERE nro_cuenta = p_nro_cuenta;
      -- se evalúa la situación de la cuenta y luego se retorna este código

      -- CCI
      IF v_cod_modalidad = 81 THEN
         SELECT con_aladi,
                confirmado,
                decode(cod_bco_corresponsal, '', 'N', 'S'), --decode(fug_obt_cod_banco(),cod_bco_corresponsal,'N','S'),
                fug_obt_ubi_banco(cod_bco_negociador),
                stand_by
           INTO v_con_aladi, v_confirmado, v_con_corresponsal, v_ubi_bco_negociador, v_stand_by
           FROM cx_cta_importaciones
          WHERE nro_cuenta = p_nro_cuenta;
         /*     NO APLICA
         if v_stand_by = 'S' and v_con_corresponsal = 'S' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'L' then
           v_sit_contable := 81000001;  --'CCI-Stand by-Con Corresp.-ALADI-Doméstica'
         elsif v_stand_by = 'S' and v_con_corresponsal = 'S' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'E' then
           v_sit_contable := 81000002;  --'CCI-Stand by-Con Corresp.-ALADI-NO Doméstica'
         elsif v_stand_by = 'S' and v_con_corresponsal = 'S' and v_con_aladi = 'N' and v_ubi_bco_negociador = 'L' then
           v_sit_contable := 81000003; -- 'CCI-Stand by-Con Corresp.-NO ALADI-Doméstica'
         els */
         IF v_stand_by = 'S' AND v_con_corresponsal = 'S' AND v_con_aladi = 'N' AND
            v_ubi_bco_negociador = 'E' THEN
            v_sit_contable := 81000004; -- 'CCI-Stand by-Con Corresp.-NO ALADI-NO Doméstica'
            /*elsif v_stand_by = 'S' and v_con_corresponsal = 'N' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'L' then
              v_sit_contable := 81000005; -- 'CCI-Stand by-Sin Corresp.-ALADI-Doméstica'
            elsif v_stand_by = 'S' and v_con_corresponsal = 'N' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'E' then
              v_sit_contable := 81000006; -- 'CCI-Stand by-Sin Corresp.-ALADI-NO Doméstica'
            elsif v_stand_by = 'S' and v_con_corresponsal = 'N' and v_con_aladi = 'N' and v_ubi_bco_negociador = 'L' then
              v_sit_contable := 81000007; -- 'CCI-Stand by-Sin Corresp.-NO ALADI-Doméstica'
            elsif v_stand_by = 'S' and v_con_corresponsal = 'N' and v_con_aladi = 'N' and v_ubi_bco_negociador = 'E' then
              v_sit_contable := 81000008; -- 'CCI-Stand by-Sin Corresp.-NO ALADI-NO Doméstica'
            elsif v_stand_by = 'N' and v_con_corresponsal = 'S' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'L' then
              v_sit_contable := 81000009;  --'CCI-NO Stand by-Con Corresp.-ALADI-Doméstica'
            */
         ELSIF v_stand_by = 'N' AND v_con_corresponsal = 'S' AND v_con_aladi = 'S' AND
               v_ubi_bco_negociador = 'E' THEN
            v_sit_contable := 81000010; --'CCI-NO Stand by-Con Corresp.-ALADI-NO Doméstica'
         ELSIF v_stand_by = 'N' AND v_con_corresponsal = 'S' AND v_con_aladi = 'N' AND
               v_ubi_bco_negociador = 'L' THEN
            v_sit_contable := 81000011; -- 'CCI-NO Stand by-Con Corresp.-NO ALADI-Doméstica'
         ELSIF v_stand_by = 'N' AND v_con_corresponsal = 'S' AND v_con_aladi = 'N' AND
               v_ubi_bco_negociador = 'E' THEN
            v_sit_contable := 81000012; -- 'CCI-NO Stand by-Con Corresp.-NO ALADI-NO Doméstica'
            /*elsif v_stand_by = 'N' and v_con_corresponsal = 'N' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'L' then
              v_sit_contable := 81000013; -- 'CCI-NO Stand by-Sin Corresp.-ALADI-Doméstica'
            elsif v_stand_by = 'N' and v_con_corresponsal = 'N' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'E' then
              v_sit_contable := 81000014; -- 'CCI-NO Stand by-Sin Corresp.-ALADI-NO Doméstica'
            */
         ELSIF v_stand_by = 'N' AND v_con_corresponsal = 'N' AND v_con_aladi = 'N' AND
               v_ubi_bco_negociador = 'L' THEN
            v_sit_contable := 81000015; -- 'CCI-NO Stand by-Sin Corresp.-NO ALADI-Doméstica'
            /*elsif v_stand_by = 'N' and v_con_corresponsal = 'N' and v_con_aladi = 'N' and v_ubi_bco_negociador = 'E' then
               v_sit_contable := 81000016; -- 'CCI-NO Stand by-Sin Corresp.-NO ALADI-NO Doméstica'
            */
         ELSE
            raise_application_error(-20007,
                                    'Situacion Contable p/ ' || p_nro_cuenta ||
                                     ' no definida. Verifique los datos de la Operación!');
         END IF;
      END IF;

      -- CCE
      IF v_cod_modalidad = 82 THEN
         SELECT con_aladi,
                confirmado,
                decode(cod_bco_corresponsal, '', 'N', 'S'),
                fug_obt_ubi_banco(cod_bco_emisor)
           INTO v_con_aladi, v_confirmado, v_con_corresponsal, v_ubi_bco_negociador
           FROM cx_cta_exportaciones
          WHERE nro_cuenta = p_nro_cuenta;

         /*     NO APLICAN ESTAS SITUACIONES
         if v_confirmado = 'S' and v_con_corresponsal = 'S' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'L' then
           v_sit_contable := 82000001;  --'CCE-Confirmada-Con Corresp.-ALADI-Doméstica'
         els*/
         IF v_confirmado = 'S' AND v_con_corresponsal = 'S' AND v_con_aladi = 'S' AND
            v_ubi_bco_negociador = 'E' THEN
            v_sit_contable := 82000002; --'CCE-Confirmada-Con Corresp.-ALADI-NO Doméstica'
         ELSIF v_confirmado = 'S' AND v_con_corresponsal = 'S' AND v_con_aladi = 'N' AND
               v_ubi_bco_negociador = 'L' THEN
            v_sit_contable := 82000003; -- 'CCE-Confirmada-Con Corresp.-NO ALADI-Doméstica'
         ELSIF v_confirmado = 'S' AND v_con_corresponsal = 'S' AND v_con_aladi = 'N' AND
               v_ubi_bco_negociador = 'E' THEN
            v_sit_contable := 82000004; -- 'CCE-Confirmada-Con Corresp.-NO ALADI-NO Doméstica'
            /*elsif v_confirmado = 'S' and v_con_corresponsal = 'N' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'L' then
              v_sit_contable := 82000005; -- 'CCE-Confirmada-Sin Corresp.-ALADI-Doméstica'
            elsif v_confirmado = 'S' and v_con_corresponsal = 'N' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'E' then
              v_sit_contable := 82000006; -- 'CCE-Confirmada-Sin Corresp.-ALADI-NO Doméstica'
            */
         ELSIF v_confirmado = 'S' AND v_con_corresponsal = 'N' AND v_con_aladi = 'N' AND
               v_ubi_bco_negociador = 'L' THEN
            v_sit_contable := 82000007; -- 'CCE-Confirmada-Sin Corresp.-NO ALADI-Doméstica'
            /*elsif v_confirmado = 'S' and v_con_corresponsal = 'N' and v_con_aladi = 'N' and v_ubi_bco_negociador = 'E' then
              v_sit_contable := 82000008; -- 'CCE-Confirmada-Sin Corresp.-NO ALADI-NO Doméstica'
            elsif v_confirmado = 'N' and v_con_corresponsal = 'S' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'L' then
              v_sit_contable := 82000009;  --'CCE-NO Confirmada-Con Corresp.-ALADI-Doméstica'
            */
         ELSIF v_confirmado = 'N' AND v_con_corresponsal = 'S' AND v_con_aladi = 'S' AND
               v_ubi_bco_negociador = 'E' THEN
            v_sit_contable := 82000010; --'CCE-NO Confirmada-Con Corresp.-ALADI-NO Doméstica'
         ELSIF v_confirmado = 'N' AND v_con_corresponsal = 'S' AND v_con_aladi = 'N' AND
               v_ubi_bco_negociador = 'L' THEN
            v_sit_contable := 82000011; -- 'CCE-NO Confirmada-Con Corresp.-NO ALADI-Doméstica'
         ELSIF v_confirmado = 'N' AND v_con_corresponsal = 'S' AND v_con_aladi = 'N' AND
               v_ubi_bco_negociador = 'E' THEN
            v_sit_contable := 82000012; -- 'CCE-NO Confirmada-Con Corresp.-NO ALADI-NO Doméstica'
            /*elsif v_confirmado = 'N' and v_con_corresponsal = 'N' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'L' then
               v_sit_contable := 82000013; -- 'CCE-NO Confirmada-Sin Corresp.-ALADI-Doméstica'
             elsif v_confirmado = 'N' and v_con_corresponsal = 'N' and v_con_aladi = 'S' and v_ubi_bco_negociador = 'E' then
               v_sit_contable := 82000014; -- 'CCE-NO Confirmada-Sin Corresp.-ALADI-NO Doméstica'
            */
         ELSIF v_confirmado = 'N' AND v_con_corresponsal = 'N' AND v_con_aladi = 'N' AND
               v_ubi_bco_negociador = 'L' THEN
            v_sit_contable := 82000015; -- 'CCE-NO Confirmada-Sin Corresp.-NO ALADI-Doméstica'
            /*elsif v_confirmado = 'N' and v_con_corresponsal = 'N' and v_con_aladi = 'N' and v_ubi_bco_negociador = 'E' then
              v_sit_contable := 82000016; -- 'CCE-NO Confirmada-Sin Corresp.-NO ALADI-NO Doméstica'
            */
         ELSE
            raise_application_error(-20007,
                                    'Situacion Contable p/ ' || p_nro_cuenta ||
                                     ' no definida. Verifique los datos de la Operación!');
         END IF;
      END IF;

      -- Cobranzas
      IF v_cod_modalidad IN (83, 84) THEN
         SELECT avalada, decode(cod_bco_corresponsal, '', 'N', 'S'), fug_obt_ubi_banco(cod_banco)
           INTO v_avalada, v_con_corresponsal, v_ubi_bco_negociador
           FROM cx_cta_cobranzas
          WHERE nro_cuenta = p_nro_cuenta;

         /*if v_avalada = 'S' and v_con_corresponsal = 'S' and v_ubi_bco_negociador = 'L' then
           v_sit_contable := 83000001;  --'COBRANZA-Avalada-Con Corresp.-Doméstica'
         els*/
         IF v_avalada = 'S' AND v_con_corresponsal = 'S' AND v_ubi_bco_negociador = 'E' AND
            v_cod_modalidad = 83 THEN
            v_sit_contable := 83000002; --'COBRANZA-Avalada-Con Corresp.-NO Doméstica'
            /*elsif v_avalada = 'S' and v_con_corresponsal = 'N' and v_ubi_bco_negociador = 'L' then
              v_sit_contable := 83000003; -- 'COBRANZA-Avalada-Sin Corresp.-Doméstica'
            elsif v_avalada = 'S' and v_con_corresponsal = 'N' and v_ubi_bco_negociador = 'E' then
              v_sit_contable := 83000004; -- 'COBRANZA-Avalada-Sin Corresp.-NO Doméstica'
            elsif v_avalada = 'N' and v_con_corresponsal = 'S' and v_ubi_bco_negociador = 'L' then
              v_sit_contable := 83000005;  --'COBRANZA-NO Avalada-Con Corresp.-Doméstica'
            */
         ELSIF v_avalada = 'N' AND v_con_corresponsal = 'S' AND v_ubi_bco_negociador = 'E' THEN
            v_sit_contable := 83000006; --'COBRANZA-NO Avalada-Con Corresp.-NO Doméstica'
            /*
            elsif v_avalada = 'N' and v_con_corresponsal = 'N' and v_ubi_bco_negociador = 'L' then
              v_sit_contable := 83000007; -- 'COBRANZA-NO Avalada-Sin Corresp.-Doméstica'
            elsif v_avalada = 'N' and v_con_corresponsal = 'N' and v_ubi_bco_negociador = 'E' then
              v_sit_contable := 83000008; -- 'COBRANZA-NO Avalada-Sin Corresp.-NO Doméstica'
            */
         ELSE
            raise_application_error(-20007,
                                    'Situacion Contable p/ ' || p_nro_cuenta ||
                                     ' no definida. Verifique los datos de la Operación!');
         END IF;
      END IF;

      -- Fianzas
      IF v_cod_modalidad IN (88, 89) THEN
         SELECT stand_by, contragarantia
           INTO v_stand_by, v_contragarantia
           FROM cx_fianzas
          WHERE nro_cuenta = p_nro_cuenta;

         IF v_stand_by = 'S' AND v_contragarantia = 'S' THEN
            v_sit_contable := 88000001; --'FIANZA-Stand by-Con Contragarantía'
         ELSIF v_stand_by = 'S' AND v_contragarantia = 'N' THEN
            v_sit_contable := 88000002; -- 'FIANZA-Stand by-Sin Contragarantía'
         ELSIF v_stand_by = 'N' AND v_contragarantia = 'S' THEN
            v_sit_contable := 88000003; --'FIANZA-NO Stand by-Con Contragarantía'
         ELSIF v_stand_by = 'N' AND v_contragarantia = 'N' THEN
            v_sit_contable := 88000004; -- 'FIANZA-NO Stand by-Sin Contragarantía'
         ELSE
            raise_application_error(-20007,
                                    'Situacion Contable p/ ' || p_nro_cuenta ||
                                     ' no definida. Verifique los datos de la Operación!');
         END IF;
      END IF;

      -- Mesa de Dinero
      IF v_cod_modulo = 10 THEN
         BEGIN
            Select d.cod_modalidad
              Into v_cod_mod_mesa
              From Md_Cta_Documentos d
             Where Nro_Cuenta = p_Nro_Cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20008,
                                       'Error al Buscar Cta. de Mesa de Dinero. ' || SQLERRM);
         END;
         --
         -- CNFREINT-1 - Repo Interbancario - RABP-CNF - CNFREINT-104
         If FUM_OBT_OPE_REPO(10,v_cod_mod_mesa,'S','R') = 'S' Then -- CNFREINT-104 - RABP-CNF
            -- Si es un REPO Recibido (Alta Repo), RE-COMPRA (Alta Instrumentos Repo).
            v_sit_contable := 10000001; -- 'Venta Doc. RE-COMPRA'
         Elsif FUM_OBT_OPE_REPO(10,v_cod_mod_mesa,'S','O') = 'S' Then -- CNFREINT-104 - RABP-CNF
            -- Si es un REPO Otorgado(Alta Repo), RE-VENTA (Alta Instrumentos Repo).
            v_sit_contable := 10000002; -- 'Compra Doc. RE-VENTA'
         ELSE
            -- Operaciones Normales.
            v_sit_contable := 10000000; -- 'Normal' -- Baja de Ctas Repo
         END IF;
      END IF;
      RETURN v_sit_contable;
   END;

   -- función que retorna un número registrado de la situación contable exacta de la operación
   FUNCTION fu_obt_sit_contable(p_nro_cuenta IN VARCHAR2) RETURN NUMBER IS
      v_sit_contable NUMBER(20);
      --
   BEGIN
      -- tomo directamente el último registro de la cuenta
      SELECT cod_sit_contable INTO v_sit_contable FROM ge_cuentas WHERE nro_cuenta = p_nro_cuenta;

      RETURN v_sit_contable;
   END;

   -- función que retorna la descripción de la situación contable
   FUNCTION fu_obt_des_sit_contable(p_cod_sit_contable IN NUMBER) RETURN VARCHAR2 IS
      v_descripcion VARCHAR2(200);
      --
   BEGIN

      SELECT descripcion
        INTO v_descripcion
        FROM TABLE(pab_asi.fu_lis_sit_contable)
       WHERE codigo = p_cod_sit_contable;

      RETURN v_descripcion;
   EXCEPTION 
     WHEN OTHERS THEN
       v_descripcion := NULL;
       RETURN v_descripcion;
   END;

   FUNCTION fu_obt_rub_contable
   (
      p_nro_cuenta IN VARCHAR2,
      p_tip_saldo  IN VARCHAR2,
      p_sit_deuda  IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2 IS
      v_cod_rubro cb_rubros.cod_rubro%TYPE;
      /******************************
      --- Tipos de saldos
      --- C = Capital
      --- F = Capital AFD
      --- I = Interes
      --- A = A devengar
      --- P = Pignoracion
      --- T = Sobregiro Transitorio
      --- B = Bancos del Pais
      --- D = Devengado
      --- S = Devengado en Suspenso
      --- Z = Saldo Iva vencido en suspenso
      --- G = Gastos
      --- V = Prevision
      --- S = Saldo en (COMEX) --> Repetido
      --- B = Act. Fijo: Depreciacion Acumulada
      --- L = Valuacion --> Valuacion
      --- E = Garantias Computables
      --- J = Garantias No Computables
      --- N = Intereses no documentados
      *********************************/
   BEGIN
      SELECT a.cod_rubro
        INTO v_cod_rubro
        FROM cb_sal_inventarios a, cb_sal_inventarios_det d
       WHERE a.nro_referencia = d.nro_referencia
         AND d.nro_cuenta = p_nro_cuenta
         AND a.tip_saldo = p_tip_saldo
         AND (p_sit_deuda IS NULL OR a.situacion = p_sit_deuda);
      RETURN v_cod_rubro;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   FUNCTION fu_obt_rub_con_his
   (
      p_nro_cuenta IN VARCHAR2,
      p_tip_saldo  IN VARCHAR2,
      p_fecha      IN DATE,
      p_sit_deuda  IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2 IS
      v_cod_rubro cb_rubros.cod_rubro%TYPE;
      /******************************
      --- Tipos de saldos
      --- C = Capital
      --- F = Capital AFD
      --- I = Interes
      --- A = A devengar
      --- P = Pignoracion
      --- T = Sobregiro Transitorio
      --- B = Bancos del Pais
      --- D = Devengado
      --- S = Devengado en Suspenso
      --- Z = Saldo Iva vencido en suspenso
      --- G = Gastos
      --- V = Prevision
      --- S = Saldo en (COMEX) --> Repetido
      --- B = Act. Fijo: Depreciacion Acumulada
      --- L = Valuacion --> Valuacion
      --- E = Garantias Computables
      --- J = Garantias No Computables
      --- N = Intereses no documentados
      *********************************/
   BEGIN
      SELECT a.cod_rubro
        INTO v_cod_rubro
        FROM cb_sal_inventarios_his a, cb_sal_inventarios_det_his d
       WHERE a.fecha = p_fecha
         AND d.fecha = a.fecha
         AND a.nro_referencia = d.nro_referencia
         AND d.nro_cuenta = p_nro_cuenta
         AND a.tip_saldo = p_tip_saldo
         AND (p_sit_deuda IS NULL OR a.situacion = p_sit_deuda);
      RETURN v_cod_rubro;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
END pab_asi;
/
