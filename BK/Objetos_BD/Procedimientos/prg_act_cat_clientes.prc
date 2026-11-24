create or replace PROCEDURE IT.PRG_ACT_CAT_CLIENTES IS
   TYPE t_bcp_row IS RECORD (
      fila             ROWID,
      tip_documento     ge_bcp_clasificacion_tmp.tip_documento%TYPE,
      nro_documento     ge_bcp_clasificacion_tmp.nro_documento%TYPE,
      cla_sistema       ge_bcp_clasificacion_tmp.cla_sistema%TYPE,
      cla_entidad       ge_bcp_clasificacion_tmp.cla_entidad%TYPE,
      tot_deu_entidad   ge_bcp_clasificacion_tmp.tot_deu_entidad%TYPE,
      tot_deu_sistema   ge_bcp_clasificacion_tmp.tot_deu_sistema%TYPE,
      tot_riesgo        ge_bcp_clasificacion_tmp.tot_riesgo%TYPE,
      tot_cou_sistema   ge_bcp_clasificacion_tmp.tot_cou_sistema%TYPE,
      tot_cou_entidad   ge_bcp_clasificacion_tmp.tot_cou_entidad%TYPE,
      tot_con_entidad   ge_bcp_clasificacion_tmp.tot_con_entidad%TYPE,
      tot_con_sistema   ge_bcp_clasificacion_tmp.tot_con_sistema%TYPE
   );

   TYPE t_bcp IS TABLE OF t_bcp_row INDEX BY PLS_INTEGER;
   TYPE t_rowid_tab IS TABLE OF ROWID INDEX BY PLS_INTEGER;

   v_bcp_clas     t_bcp;
   v_rowids       t_rowid_tab;

   TYPE T_GE_BCP_CLAS_TMP IS TABLE OF VARCHAR2(50) INDEX BY PLS_INTEGER;
   v_ge_bcp_clas_tmp T_GE_BCP_CLAS_TMP;

   v_cod_tip_documento ba_tip_documentos.cod_tip_documento%TYPE;
   v_cod_persona       ge_clientes.cod_persona%TYPE;
   v_cod_oficina       ba_oficinas.cod_oficina%TYPE;
   v_fecha             DATE;
   v_existe            VARCHAR2(01);
   v_lugar             VARCHAR2(100);

   v_can_commit         PLS_INTEGER := 0;
   v_tip_implementacion NUMBER := FUG_OBT_TIP_IMPLEMENTACION;
   c_limit              PLS_INTEGER := fug_obt_pardinamico('VAL_PAG_ACT_CAT');

BEGIN
   -- Inicializar los datos de los clientes
   -- CRIN0010, es el Archivo recibido en ascii de BCP y utilizado
   -- para informacion de riesgos de CRC volcado en GE_BCP_CLASIFICACION_TMP
   V_LUGAR := 'Al actualizar ge_clientes (Limpieza Inicial)';
   LOOP
      SELECT ROWID
      BULK COLLECT INTO v_rowids
      FROM ge_clientes
        WHERE (
                 NVL(tot_deu_sistema, 0)     != 0
              OR NVL(tot_deu_cod_sistema, 0) <> 0
              OR NVL(tot_deu_con_sistema, 0) <> 0
              )
          AND ROWNUM <= c_limit;

      EXIT WHEN v_rowids.COUNT = 0;

      FORALL i IN 1 .. v_rowids.COUNT
         UPDATE ge_clientes
            SET cat_sistema         = NULL,
                tot_deu_sistema     = 0,
                tot_deu_cod_sistema = 0,
                tot_deu_codeudoria  = 0,
                tot_deu_con_sistema = 0
          WHERE ROWID = v_rowids(i);

      COMMIT;
   END LOOP;
   -- Se agrego esto porque cuando los datos se envian a BCP ellos exigen
   -- que el CRP tenga 4 digitos en los primeros nros.
   -- pero cuando ellos envian los datos lo hacen sin el primer cero
   V_LUGAR := 'Al actualizar ge_bcp_clasificacion_tmp';
   
    SELECT nro_documento
      BULK COLLECT INTO v_ge_bcp_clas_tmp
      FROM ge_bcp_clasificacion_tmp
     WHERE tip_documento = 'CRP' AND nro_documento LIKE '___-%';
    
    FORALL i IN 1 .. v_ge_bcp_clas_tmp.COUNT
       UPDATE ge_bcp_clasificacion_tmp
          SET nro_documento = '0' || nro_documento
        WHERE nro_documento = v_ge_bcp_clas_tmp(i);

   V_LUGAR := 'Al cargar temporal ge_bcp_clasificacion_tmp';
   SELECT ROWID, 
          rtrim(tip_documento) tip_documento, 
           nro_documento,
           CASE 
            WHEN cla_sistema IN ('1a', '1b') THEN '1'
            ELSE cla_sistema
           END cla_sistema,                         -- Clasificacion del Sistema
           CASE 
            WHEN cla_entidad IN ('1a', '1b') THEN '1'
            ELSE cla_entidad
           END cla_entidad,                         -- Clasificacion de la Entidad
           nvl(tot_deu_entidad, 0) tot_deu_entidad, -- Total Deuda Contable de la Entidad.
           nvl(tot_deu_sistema, 0) tot_deu_sistema, -- Total Deuda Contable resto del Sistema.
           tot_riesgo,                              -- Total Deuda + Contingencia + Codeuderia
           tot_cou_sistema,                         -- Total Codeudoria Resto del Sistema
		   tot_cou_entidad,                         -- Total Codeudoria en la Entidad
		   tot_con_entidad,                         -- Total Contingencia en la Entidad
		   tot_con_sistema                          -- Total Contingencia Resto del Sistema
   BULK COLLECT INTO v_bcp_clas
   FROM ge_bcp_clasificacion_tmp
   WHERE cod_persona IS NULL;

   FOR i IN 1 .. v_bcp_clas.COUNT LOOP

    IF FUE_VAL_ES_NUMERICO(v_bcp_clas(i).nro_documento) = 'S' 
    THEN
        v_bcp_clas(i).nro_documento := TO_CHAR(TO_NUMBER(v_bcp_clas(i).nro_documento));
    ELSE
        v_bcp_clas(i).nro_documento := LTRIM(RTRIM(v_bcp_clas(i).nro_documento));
    END IF; 

      IF v_bcp_clas(i).tip_documento IS NOT NULL THEN
      v_lugar := 'Al obtener el codigo del tipo del documento:' || v_bcp_clas(i).tip_documento||'-'||v_bcp_clas(i).nro_documento;
         BEGIN
            -- Obtener el codigo del tipo del documento
            SELECT cod_tip_documento
              INTO v_cod_tip_documento
              FROM ba_tip_documentos
             WHERE abreviatura = v_bcp_clas(i).tip_documento;

            BEGIN
               -- Obtener el codigo del cliente
               SELECT cod_persona
                 INTO v_cod_persona
                 FROM ba_personas
                WHERE cod_tip_documento = v_cod_tip_documento
                  AND nro_documento = v_bcp_clas(i).nro_documento;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_cod_persona := NULL;
            END;
         EXCEPTION
            WHEN OTHERS THEN
               v_cod_persona := NULL;
         END;
      END IF;

      IF v_cod_persona IS NOT NULL THEN
         UPDATE ge_clientes
            SET cat_sistema         = v_bcp_clas(i).cla_sistema,
                tot_deu_sistema     = v_bcp_clas(i).tot_deu_sistema,
                tot_deu_cod_sistema = v_bcp_clas(i).tot_cou_sistema,
                tot_deu_codeudoria  = v_bcp_clas(i).tot_cou_entidad,
                tot_deu_con_sistema = v_bcp_clas(i).tot_con_sistema
          WHERE cod_persona = v_cod_persona;

         IF SQL%ROWCOUNT = 0 THEN
            IF v_tip_implementacion = 2 THEN
               -- Obtener oficina del usuario
               SELECT cod_oficina
                 INTO v_cod_oficina
                 FROM ba_usuarios
                WHERE cod_usuario = SUBSTR(USER, 1, 10);

               INSERT INTO ge_clientes
                  (cod_persona, cod_oficina, exo_impuestos, cod_usu_oficial, cli_especial,
                   residente, cod_sec_contable, cod_tip_deudor, tip_extracto, cli_confidencial,
                   cat_sistema, tot_deu_sistema)
               VALUES
                  (v_cod_persona, v_cod_oficina, 'N', SUBSTR(USER, 1, 10), 'N',
                   'S', 'N', 2, 'C', 'N',
                   v_bcp_clas(i).cla_sistema, v_bcp_clas(i).tot_riesgo);
            END IF;
         END IF;

         UPDATE ge_bcp_clasificacion_tmp
            SET cod_persona = v_cod_persona
          WHERE ROWID = v_bcp_clas(i).fila;
      END IF;

      v_can_commit := v_can_commit + 1;
      IF v_can_commit >= c_limit THEN
         COMMIT;
         v_can_commit := 0;
      END IF;
   END LOOP;

   COMMIT;

   -- Llevar al historico
   BEGIN
      SELECT MAX(TO_DATE(PERIODO, 'YYYY/MM/DD')) 
        INTO v_fecha
        from ge_bcp_clasificacion_tmp
      where rownum = 1;
      
      --Verificar si existe los datos
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM ge_bcp_clasificacion_his
          WHERE fec_proceso = v_fecha
            AND rownum = 1;
 
      EXCEPTION
         WHEN no_data_found THEN
            DECLARE
                CURSOR c_ge_bcp_clasificacion_tmp IS
                 SELECT tip_documento, nro_documento, tip_formulario, nombre, apellido, fec_nacimiento,
                    fec_baja, cla_entidad, cla_sistema, tot_deu_entidad, tot_deu_sistema, tot_con_entidad,
                    tot_con_sistema, tot_cou_entidad, tot_cou_sistema, tot_riesgo, nro_registro, cod_persona,
                    periodo
                 FROM ge_bcp_clasificacion_tmp;
   
                TYPE T_BATCH IS TABLE OF c_ge_bcp_clasificacion_tmp%ROWTYPE;
                v_batch T_BATCH;
   
                BATCH_SIZE CONSTANT PLS_INTEGER := 5000;

            BEGIN
               OPEN c_ge_bcp_clasificacion_tmp;
               LOOP
                  FETCH c_ge_bcp_clasificacion_tmp BULK COLLECT INTO v_batch LIMIT BATCH_SIZE;
                  
                  EXIT WHEN v_batch.COUNT = 0;

                  FORALL i IN 1..v_batch.COUNT
                     INSERT /*+ APPEND */ INTO ge_bcp_clasificacion_his
                     (fec_proceso, tip_documento, nro_documento, tip_formulario, nombre, apellido, fec_nacimiento,
                      fec_baja, cla_entidad, cla_sistema, tot_deu_entidad, tot_deu_sistema, tot_con_entidad,
                      tot_con_sistema, tot_cou_entidad, tot_cou_sistema, tot_riesgo, nro_registro, cod_persona,
                      periodo)
                     VALUES (v_fecha, 
                             v_batch(i).tip_documento, v_batch(i).nro_documento, v_batch(i).tip_formulario,
                             v_batch(i).nombre, v_batch(i).apellido, v_batch(i).fec_nacimiento, v_batch(i).fec_baja,
                             v_batch(i).cla_entidad, v_batch(i).cla_sistema, v_batch(i).tot_deu_entidad, 
                             v_batch(i).tot_deu_sistema, v_batch(i).tot_con_entidad, v_batch(i).tot_con_sistema, 
                             v_batch(i).tot_cou_entidad, v_batch(i).tot_cou_sistema, v_batch(i).tot_riesgo, 
                             v_batch(i).nro_registro, v_batch(i).cod_persona, v_batch(i).periodo);
               END LOOP;

               CLOSE c_ge_bcp_clasificacion_tmp;
            END;
      END;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Al insertar al Historico' || SQLERRM);
   END;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,V_LUGAR || ' - ' ||SQLERRM);

END PRG_ACT_CAT_CLIENTES;
/
