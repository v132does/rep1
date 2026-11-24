CREATE OR REPLACE PROCEDURE it.prg_ins_per_vinculos IS
  v_cod_persona     ba_personas.cod_persona%TYPE;
  v_cod_per_vinculo ba_personas.cod_persona%TYPE;
  v_cantidad        INTEGER;
  v_existe          VARCHAR2(1) := 'N';
  v_acc_por         VARCHAR2(1) := 'N';
  v_exi_acc         VARCHAR2(20);
  v_exi_por_part    VARCHAR2(20);
  v_exi_acc_prin    VARCHAR2(20);
  v_exi_can_part    VARCHAR2(20);
  v_exi_imp_part    VARCHAR2(20);
  v_exi_tot_part    VARCHAR2(20);
  CURSOR c_personas IS
    SELECT upper(TRIM(t.primer_nombre) || ' ' || TRIM(t.segundo_nombre) || ' ' ||
                 TRIM(t.primer_apellido) || ' ' || TRIM(t.segundo_apellido)) nombre_completo,
           decode(t.tipo_documento, 'RUC', 'J', 'F') tipo,
           d.cod_tip_documento,
           t.nro_documento,
           246 pais,
           upper(t.primer_nombre) pri_nombre,
           upper(t.segundo_nombre) seg_nombre,
           upper(t.primer_apellido) pri_apellido,
           upper(t.segundo_apellido) seg_apellido,
           v.cod_tip_vinculo,
           t.acc_portador,
           t.can_acciones,
           t.valor,
           t.total,
           t.por_participacion,
           t.nro_doc_persona,
           t.tip_doc_persona
      FROM tm_per_vinculos t, ba_tip_documentos d, ba_tip_vinculos v
     WHERE upper(TRIM(t.tipo_documento)) = d.abreviatura
       AND upper(TRIM(t.tipo_vinculo)) = upper(v.descripcion)
       AND nvl(t.procesado, 'N') = 'N';
BEGIN
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
  FOR r_cup IN c_personas
  LOOP
    --Verifico Persona
    BEGIN
      SELECT b.cod_persona
        INTO v_cod_persona
        FROM ba_personas b, ba_tip_documentos d
       WHERE b.nro_documento = r_cup.nro_doc_persona
         AND d.abreviatura = upper(TRIM(r_cup.tip_doc_persona));
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,
                                'Error al buscar Persona con Nro.Doc.: ' ||
                                r_cup.nro_doc_persona || ' ' || SQLERRM);
    END;
    --Valido persona a vincular
    SELECT COUNT(*)
      INTO v_cantidad
      FROM ba_personas t
     WHERE t.nro_documento = r_cup.nro_documento
       AND t.cod_tip_documento = r_cup.cod_tip_documento;
    --Si no existe, inserta nueva persona
    IF v_cantidad = 0 THEN
      SELECT s_cod_persona.nextval INTO v_cod_per_vinculo FROM dual;
      BEGIN
        INSERT INTO ba_personas
          (cod_persona,
           nom_completo,
           tipo,
           cod_tip_documento,
           nro_documento,
           cod_pais,
           cod_rub_primario,
           cod_actividad,
           est_verificacion,
           obs_verificacion,
           fec_verificacion)
        VALUES
          (v_cod_per_vinculo,
           r_cup.nombre_completo,
           r_cup.tipo,
           r_cup.cod_tip_documento,
           r_cup.nro_documento,
           r_cup.pais,
           749911,
           fug_obt_cod_actividad(749911),
           'V',
           'IMP. DATOS DE PERSONAS VINCULADAS',
           SYSDATE);
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error insert ba_personas ' || SQLERRM);
      END;
      IF nvl(r_cup.tipo, 'X') = 'F' THEN
        BEGIN
          INSERT INTO ba_per_fisicas
            (cod_persona,
             pri_nombre,
             pri_apellido,
             seg_nombre,
             seg_apellido)
          VALUES
            (v_cod_per_vinculo,
             substr(r_cup.pri_nombre, 1, 30),
             substr(r_cup.pri_apellido, 1, 30),
             substr(r_cup.seg_nombre, 1, 30),
             substr(r_cup.seg_apellido, 1, 30));
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error insert ba_per_fisicas ' ||
                                    SQLERRM);
        END;
      END IF;
      IF nvl(r_cup.tipo, 'X') = 'J' THEN
        BEGIN
          INSERT INTO ba_per_juridicas
            (cod_persona, raz_social, nom_comercial)
          VALUES
            (v_cod_per_vinculo,
             r_cup.nombre_completo,
             r_cup.nombre_completo);
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error insert ba_per_juridicas ' ||
                                    SQLERRM);
        END;
      END IF;
    ELSE
      --Si existe la persona, busca codigo persona
      BEGIN
        SELECT t.cod_persona
          INTO v_cod_per_vinculo
          FROM ba_personas t
         WHERE t.nro_documento = r_cup.nro_documento
           AND t.cod_tip_documento = r_cup.cod_tip_documento;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20001,
                                  'Error al buscar Persona con Nro.Doc.: ' ||
                                  r_cup.nro_doc_persona || ' ' || SQLERRM);
      END;
    END IF; -- finaliza la insercion en ba_personas
    --verificar si existe vinculo
    BEGIN
      SELECT DISTINCT ('S')
        INTO v_existe
        FROM ba_vinculos t
       WHERE t.cod_persona = v_cod_persona
         AND t.cod_per_vinculo = v_cod_per_vinculo
         AND t.tipo = r_cup.cod_tip_vinculo;
    EXCEPTION
      WHEN no_data_found THEN
        v_existe := 'N';
    END;
    --Inserto vinculo
    IF v_existe = 'N' THEN
      BEGIN
        INSERT INTO ba_vinculos
          (cod_persona, cod_per_vinculo, tipo, estado, activo)
        VALUES
          (v_cod_persona,
           v_cod_per_vinculo,
           r_cup.cod_tip_vinculo,
           'A',
           'S');
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000,
                                  'Error al insertar ba_vinculos ' ||
                                  SQLERRM);
      END;
    END IF;
    IF r_cup.acc_portador IS NOT NULL THEN
      IF UPPER(r_cup.acc_portador) = 'SI' THEN
        v_acc_por := 'S';
      ELSIF UPPER(r_cup.acc_portador) = 'NO' THEN
        v_acc_por := 'N';
      END IF;
      ---ba_per_dat_adicionales ACC_PORTADOR principal
      BEGIN
        SELECT nvl(p.val_parametro, 'N')
          INTO v_exi_acc_prin
          FROM ba_per_dat_adicionales p
         WHERE p.cod_persona = v_cod_persona
           AND p.parametro = 'ACC_PORTADOR';
      EXCEPTION
        WHEN OTHERS THEN
          v_exi_acc_prin := 'N';
          --raise_application_error(-20000,'Error al buscar ba_per_dat_adicionales ACC_PORTADOR '||v_cod_per_vinculo||' '||'ACC_PORTADOR:'||v_cod_persona);
      END;
      IF SQL%NOTFOUND THEN
        BEGIN
          INSERT INTO ba_per_dat_adicionales
            (cod_persona, parametro, val_parametro)
          VALUES
            (v_cod_persona, 'ACC_PORTADOR', v_acc_por);
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error al insertar ba_per_dat_adicionales ACC_PORTADOR ' ||
                                    SQLERRM);
        END;
      ELSE
        IF v_exi_acc_prin <> v_acc_por THEN
          UPDATE ba_per_dat_adicionales
             SET val_parametro = v_acc_por
           WHERE cod_persona = v_cod_persona
             AND parametro = 'ACC_PORTADOR';
        END IF;
      END IF;
      ---ba_per_dat_adicionales ACC_PORTADOR PER VINCULO
      BEGIN
        SELECT nvl(p.val_parametro, 'N')
          INTO v_exi_acc
          FROM ba_per_dat_adicionales p
         WHERE p.cod_persona = v_cod_per_vinculo
           AND p.parametro = 'ACC_PORTADOR:' || v_cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
          v_exi_acc := 'N';
          --raise_application_error(-20000,'Error al buscar ba_per_dat_adicionales ACC_PORTADOR '||v_cod_per_vinculo||' '||'ACC_PORTADOR:'||v_cod_persona);
      END;
      IF SQL%NOTFOUND THEN
        BEGIN
          INSERT INTO ba_per_dat_adicionales
            (cod_persona, parametro, val_parametro)
          VALUES
            (v_cod_per_vinculo, 'ACC_PORTADOR:' || v_cod_persona, v_acc_por);
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error al insertar ba_per_dat_adicionales ACC_PORTADOR ' ||
                                    SQLERRM);
        END;
      ELSE
        IF v_exi_acc <> v_acc_por THEN
          UPDATE ba_per_dat_adicionales
             SET val_parametro = v_acc_por
           WHERE cod_persona = v_cod_per_vinculo
             AND parametro = 'ACC_PORTADOR:' || v_cod_persona;
        END IF;
      END IF;
    END IF;
    --   ba_per_dat_adicionales  POR_PARTICIPACION
    IF r_cup.por_participacion IS NOT NULL THEN
      BEGIN
        SELECT nvl(p.val_parametro, '0')
          INTO v_exi_por_part
          FROM ba_per_dat_adicionales p
         WHERE p.cod_persona = v_cod_per_vinculo
           AND p.parametro = 'POR_PARTICIPACION:' || r_cup.cod_tip_vinculo ||
               v_cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
          v_exi_por_part := '0';
          --raise_application_error(-20000,'Error al buscar ba_per_dat_adicionales ACC_PORTADOR '||v_cod_per_vinculo||' '||'ACC_PORTADOR:'||v_cod_persona);
      END;
      IF SQL%NOTFOUND THEN
        BEGIN
          INSERT INTO ba_per_dat_adicionales
            (cod_persona, parametro, val_parametro)
          VALUES
            (v_cod_per_vinculo,
             'POR_PARTICIPACION:' || r_cup.cod_tip_vinculo || v_cod_persona,
             r_cup.por_participacion);
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error al insertar ba_per_dat_adicionales POR_PARTICIPACION ' ||
                                    SQLERRM);
        END;
      ELSE
        IF v_exi_por_part <> r_cup.por_participacion THEN
          UPDATE ba_per_dat_adicionales
             SET val_parametro = r_cup.por_participacion
           WHERE cod_persona = v_cod_per_vinculo
             AND parametro = 'POR_PARTICIPACION:' || r_cup.cod_tip_vinculo ||
                 v_cod_persona;
        END IF;
      END IF;
    END IF;
    --   ba_per_dat_adicionales  CAN_PARTICIPACION
    IF r_cup.can_acciones IS NOT NULL THEN
      BEGIN
        SELECT nvl(p.val_parametro, '0')
          INTO v_exi_can_part
          FROM ba_per_dat_adicionales p
         WHERE p.cod_persona = v_cod_per_vinculo
           AND p.parametro = 'CAN_PARTICIPACION:' || r_cup.cod_tip_vinculo ||
               v_cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
          v_exi_can_part := '0';
          --raise_application_error(-20000,'Error al buscar ba_per_dat_adicionales ACC_PORTADOR '||v_cod_per_vinculo||' '||'ACC_PORTADOR:'||v_cod_persona);
      END;
      IF SQL%NOTFOUND THEN
        BEGIN
          INSERT INTO ba_per_dat_adicionales
            (cod_persona, parametro, val_parametro)
          VALUES
            (v_cod_per_vinculo,
             'CAN_PARTICIPACION:' || r_cup.cod_tip_vinculo || v_cod_persona,
             r_cup.can_acciones);
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error al insertar ba_per_dat_adicionales CAN_PARTICIPACION ' ||
                                    SQLERRM);
        END;
      ELSE
        IF v_exi_can_part <> r_cup.can_acciones THEN
          UPDATE ba_per_dat_adicionales
             SET val_parametro = r_cup.can_acciones
           WHERE cod_persona = v_cod_per_vinculo
             AND parametro = 'CAN_PARTICIPACION:' || r_cup.cod_tip_vinculo ||
                 v_cod_persona;
        END IF;
      END IF;
    END IF;
    --   ba_per_dat_adicionales  IMP_PARTICIPACION
    IF r_cup.valor IS NOT NULL THEN
      BEGIN
        SELECT nvl(p.val_parametro, '0')
          INTO v_exi_imp_part
          FROM ba_per_dat_adicionales p
         WHERE p.cod_persona = v_cod_per_vinculo
           AND p.parametro = 'IMP_PARTICIPACION:' || r_cup.cod_tip_vinculo ||
               v_cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
          v_exi_imp_part := '0';
          --raise_application_error(-20000,'Error al buscar ba_per_dat_adicionales ACC_PORTADOR '||v_cod_per_vinculo||' '||'ACC_PORTADOR:'||v_cod_persona);
      END;
      IF SQL%NOTFOUND THEN
        BEGIN
          INSERT INTO ba_per_dat_adicionales
            (cod_persona, parametro, val_parametro)
          VALUES
            (v_cod_per_vinculo,
             'IMP_PARTICIPACION:' || r_cup.cod_tip_vinculo || v_cod_persona,
             r_cup.valor);
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error al insertar ba_per_dat_adicionales IMP_PARTICIPACION ' ||
                                    SQLERRM);
        END;
      ELSE
        IF v_exi_imp_part <> r_cup.valor THEN
          UPDATE ba_per_dat_adicionales
             SET val_parametro = r_cup.valor
           WHERE cod_persona = v_cod_per_vinculo
             AND parametro = 'IMP_PARTICIPACION:' || r_cup.cod_tip_vinculo ||
                 v_cod_persona;
        END IF;
      END IF;
    END IF;
    --   ba_per_dat_adicionales  TOT_PARTICIPACION
    IF r_cup.total IS NOT NULL THEN
      BEGIN
        SELECT nvl(p.val_parametro, '0')
          INTO v_exi_tot_part
          FROM ba_per_dat_adicionales p
         WHERE p.cod_persona = v_cod_per_vinculo
           AND p.parametro = 'TOT_PARTICIPACION:' || r_cup.cod_tip_vinculo ||
               v_cod_persona;
      EXCEPTION
        WHEN OTHERS THEN
          v_exi_tot_part := '0';
          --raise_application_error(-20000,'Error al buscar ba_per_dat_adicionales ACC_PORTADOR '||v_cod_per_vinculo||' '||'ACC_PORTADOR:'||v_cod_persona);
      END;
      IF SQL%NOTFOUND THEN
        BEGIN
          INSERT INTO ba_per_dat_adicionales
            (cod_persona, parametro, val_parametro)
          VALUES
            (v_cod_per_vinculo,
             'TOT_PARTICIPACION:' || r_cup.cod_tip_vinculo || v_cod_persona,
             r_cup.total);
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error al insertar ba_per_dat_adicionales TOT_PARTICIPACION ' ||
                                    SQLERRM);
        END;
      ELSE
        IF v_exi_tot_part <> r_cup.total THEN
          UPDATE ba_per_dat_adicionales
             SET val_parametro = r_cup.total
           WHERE cod_persona = v_cod_per_vinculo
             AND parametro = 'TOT_PARTICIPACION:' || r_cup.cod_tip_vinculo ||
                 v_cod_persona;
        END IF;
      END IF;
    END IF;
    --Procesa registro
    BEGIN
      UPDATE tm_per_vinculos t
         SET t.procesado = 'S', 
             t.fecha = SYSDATE
       WHERE t.nro_doc_persona = r_cup.nro_doc_persona
         AND t.nro_documento = r_cup.nro_documento
         AND nvl(t.procesado, 'N') = 'N';
    END;
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error prg_ins_per_vinculos' || SQLERRM);
END;
/
