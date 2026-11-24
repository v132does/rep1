CREATE OR REPLACE PROCEDURE IT.PRB_GEN_ASI_GARANTIAS IS
   -- Variables locales principales
   rv_gcale            ge_calendarios%ROWTYPE;
   v_fec_actual        ge_calendarios.fec_actual%TYPE;
   v_fec_anterior      ge_calendarios.fec_anterior%TYPE;
   v_redondeo          NUMBER(1);
   v_cod_mon_local     ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_usuario           ba_usuarios.cod_usuario%TYPE;
   v_can_user          NUMBER;
   v_ofi_matriz        ge_movimientos.cod_oficina%TYPE;
   
   -- Variable récord reutilizable por los subprogramas
   r_gmovi             ge_movimientos%ROWTYPE;

   -- Control de usuarios y secuencias
   TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
   v_usu_secuencia typ_usu_secuencia;

   TYPE typ_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
   v_usu_hora      typ_usu_hor;

   -- Caché en memoria para parámetros dinámicos
   TYPE typ_cache_num IS TABLE OF NUMBER INDEX BY VARCHAR2(100);
   v_cache_red     typ_cache_num;
   v_key_red       VARCHAR2(100);

   -- Centraliza la rotación de secuencias y usuarios
   PROCEDURE lp_asignar_secuencia_usuario IS
   BEGIN
      IF v_usuario IS NULL OR NOT v_usu_secuencia.EXISTS(v_usuario) OR v_usu_secuencia(v_usuario) >= 997 THEN
         v_usuario                  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE', 'USU_MOV_CIERRE', v_can_user, 'S_USU_MOVCIERRE');
         v_usu_hora(v_usuario)      := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE', 'E');
         v_usu_secuencia(v_usuario) := -999;
      END IF;
      v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
   END lp_asignar_secuencia_usuario;

   --- Procedimiento de Desafectación
   PROCEDURE lp_gen_asi_desafectacion IS
      CURSOR c_desafectacion IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                NVL(a.cod_oficina, v_ofi_matriz) AS cod_oficina,
                a.cod_moneda,
                a.cod_tra_padre,
                a.cod_transaccion,
                a.monto * -1 AS monto,
                a.estado,
                'DESAFECTACION GARANTIA' || DECODE(a.cod_transaccion, t.cod_transaccion1, '(comp)', '(nocomp)') AS concepto,
                a.reversado,
                a.cod_mod_padre,
                a.cod_mad_padre,
                a.nro_cuenta,
                a.cod_ofi_origen,
                a.cod_rubro,
                a.tip_mov_rubro,
                a.cod_persona,
                a.nro_documento
           FROM ge_movimientos_ant a
           JOIN pr_gar_tipos t
             ON a.cod_modulo    = t.cod_modulo
            AND a.cod_modalidad = t.cod_modalidad
            AND a.referencia    = t.cod_garantia
            AND a.cod_transaccion IN (t.cod_transaccion1, t.cod_transaccion2)
          WHERE a.fecha         = v_fec_anterior
            AND a.cod_tra_padre = 200
            AND a.monto         > 0
          ORDER BY a.hora, a.nro_secuencia;

      TYPE t_desafectacion IS TABLE OF c_desafectacion%ROWTYPE;
      v_list t_desafectacion;

      TYPE t_ge_mov IS TABLE OF ge_movimientos%ROWTYPE INDEX BY PLS_INTEGER;
      v_ins_mov t_ge_mov;
   BEGIN
      OPEN c_desafectacion;
      LOOP
         FETCH c_desafectacion BULK COLLECT INTO v_list LIMIT 5000;
         EXIT WHEN v_list.COUNT = 0;

         v_ins_mov.DELETE;

         FOR i IN 1..v_list.COUNT LOOP
            r_gmovi := NULL; -- Limpieza de récord por iteración
            
            lp_asignar_secuencia_usuario;

            r_gmovi.cod_modulo      := v_list(i).cod_modulo;
            r_gmovi.cod_modalidad   := v_list(i).cod_modalidad;
            r_gmovi.cod_oficina     := v_list(i).cod_oficina;
            r_gmovi.cod_moneda      := v_list(i).cod_moneda;
            r_gmovi.cod_tra_padre   := v_list(i).cod_tra_padre;
            r_gmovi.cod_transaccion := v_list(i).cod_transaccion;
            r_gmovi.fecha           := v_fec_actual;
            r_gmovi.fec_valor       := v_fec_actual;
            r_gmovi.monto           := v_list(i).monto;
            r_gmovi.estado          := v_list(i).estado;
            r_gmovi.concepto        := v_list(i).concepto;
            r_gmovi.reversado       := v_list(i).reversado;
            r_gmovi.cod_mod_padre   := v_list(i).cod_mod_padre;
            r_gmovi.cod_mad_padre   := v_list(i).cod_mad_padre;
            r_gmovi.cod_usuario     := v_usuario;
            r_gmovi.hora            := v_usu_hora(v_usuario);
            r_gmovi.nro_secuencia   := v_usu_secuencia(v_usuario);
            r_gmovi.nro_cuenta      := v_list(i).nro_cuenta;
            r_gmovi.cod_ofi_origen  := v_list(i).cod_ofi_origen;
            r_gmovi.cod_rubro       := v_list(i).cod_rubro;
            r_gmovi.tip_mov_rubro   := v_list(i).tip_mov_rubro;
            r_gmovi.cod_persona     := v_list(i).cod_persona;
            r_gmovi.nro_documento   := v_list(i).nro_documento;

            v_ins_mov(v_ins_mov.COUNT + 1) := r_gmovi;
         END LOOP;

         IF v_ins_mov.COUNT > 0 THEN
            FORALL i IN 1..v_ins_mov.COUNT
               INSERT INTO ge_movimientos (
                  cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_tra_padre,
                  cod_transaccion, fecha, fec_valor, monto, estado,
                  concepto, reversado, cod_mod_padre, cod_mad_padre, cod_usuario,
                  hora, nro_secuencia, nro_cuenta, cod_ofi_origen, cod_rubro,
                  tip_mov_rubro, cod_persona, nro_documento
               ) VALUES (
                  v_ins_mov(i).cod_modulo, v_ins_mov(i).cod_modalidad, v_ins_mov(i).cod_oficina, v_ins_mov(i).cod_moneda, v_ins_mov(i).cod_tra_padre,
                  v_ins_mov(i).cod_transaccion, v_ins_mov(i).fecha, v_ins_mov(i).fec_valor, v_ins_mov(i).monto, v_ins_mov(i).estado,
                  v_ins_mov(i).concepto, v_ins_mov(i).reversado, v_ins_mov(i).cod_mod_padre, v_ins_mov(i).cod_mad_padre, v_ins_mov(i).cod_usuario,
                  v_ins_mov(i).hora, v_ins_mov(i).nro_secuencia, v_ins_mov(i).nro_cuenta, v_ins_mov(i).cod_ofi_origen, v_ins_mov(i).cod_rubro,
                  v_ins_mov(i).tip_mov_rubro, v_ins_mov(i).cod_persona, v_ins_mov(i).nro_documento
               );
         END IF;
      END LOOP;
      CLOSE c_desafectacion;

   EXCEPTION
      WHEN OTHERS THEN
         IF c_desafectacion%ISOPEN THEN
            CLOSE c_desafectacion;
         END IF;          
         raise_application_error(-20000, 'ERROR. DESAFECTACION GARANTIA: ' || SQLERRM || 
                                         ' | Trace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
   END lp_gen_asi_desafectacion;

   --- Procedimiento de Procesar Garantías 
   PROCEDURE lp_gen_asi_procesar_garantias IS
      CURSOR c_garantias IS
         SELECT g.cod_persona,
                tg.pri_aplicacion,
                t.cod_garantia,
                t.nro_garantia,
                NVL(g.cod_oficina, v_ofi_matriz) AS cod_oficina,
                g.cod_moneda,
                SUM(t.mto_dis_garantia) AS monto,
                tg.cod_modulo,
                tg.cod_modalidad,
                t.cod_transaccion,
                t.clasificacion
           FROM cb_sal_inv_garantias t
           JOIN pr_garantias g    ON t.nro_garantia = g.nro_garantia
           JOIN pr_gar_tipos tg   ON t.cod_garantia = tg.cod_garantia
          WHERE t.fecha         = v_fec_actual
            AND t.clasificacion IN ('COMPUTABLE', 'NO COMPUTABLE')
          GROUP BY g.cod_persona, tg.pri_aplicacion, t.cod_garantia, t.nro_garantia, g.cod_oficina,
                   g.cod_moneda, tg.cod_modulo, tg.cod_modalidad, t.cod_transaccion, t.clasificacion
          ORDER BY t.clasificacion, g.cod_persona, tg.pri_aplicacion, t.cod_garantia, t.nro_garantia;

      TYPE t_gar_list IS TABLE OF c_garantias%ROWTYPE;
      v_gar_list t_gar_list;

      TYPE t_ge_mov IS TABLE OF ge_movimientos%ROWTYPE INDEX BY PLS_INTEGER;
      v_ins_mov t_ge_mov;
   BEGIN
      OPEN c_garantias;
      LOOP
         FETCH c_garantias BULK COLLECT INTO v_gar_list LIMIT 2000;
         EXIT WHEN v_gar_list.COUNT = 0;

         v_ins_mov.DELETE;

         FOR i IN 1..v_gar_list.COUNT LOOP
            r_gmovi := NULL;

            IF v_gar_list(i).cod_transaccion IS NULL THEN
               raise_application_error(-20000, 'Transacción No definida. Cod.Garantía:' || v_gar_list(i).cod_garantia);
            END IF;
            
            v_key_red := v_gar_list(i).cod_modulo || '_' || v_gar_list(i).cod_modalidad || '_' || v_gar_list(i).cod_moneda || '_' || v_gar_list(i).cod_oficina;

            IF NOT v_cache_red.EXISTS(v_key_red) THEN
               v_cache_red(v_key_red) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                                             v_gar_list(i).cod_modulo,
                                                             v_gar_list(i).cod_modalidad,
                                                             v_gar_list(i).cod_moneda,
                                                             v_gar_list(i).cod_oficina);
            END IF;
            v_redondeo := v_cache_red(v_key_red);

            r_gmovi.nro_documento2 := NULL;
            IF v_gar_list(i).cod_moneda <> v_cod_mon_local THEN
               r_gmovi.monto         := ROUND(pag_gen.fu_con_mon_a_moneda(v_cod_mon_local, v_gar_list(i).cod_moneda, v_gar_list(i).monto), v_redondeo);
               r_gmovi.mto_equ_local := ROUND(v_gar_list(i).monto, v_redondeo);
            ELSE
               r_gmovi.monto         := ROUND(v_gar_list(i).monto, v_redondeo);
               r_gmovi.mto_equ_local := NULL;
            END IF;

            IF NVL(r_gmovi.monto, 0) <> 0 THEN
               lp_asignar_secuencia_usuario;

               r_gmovi.nro_secuencia      := v_usu_secuencia(v_usuario);
               r_gmovi.fecha              := v_fec_actual;
               r_gmovi.hora               := v_usu_hora(v_usuario);
               r_gmovi.cod_usuario        := v_usuario;
               r_gmovi.fec_valor          := v_fec_actual;
               r_gmovi.nro_cuenta         := NULL;
               r_gmovi.cod_moneda         := v_gar_list(i).cod_moneda;
               r_gmovi.cod_oficina        := v_gar_list(i).cod_oficina;
               r_gmovi.cod_ofi_origen     := v_gar_list(i).cod_oficina;
               r_gmovi.estado             := 'N';
               r_gmovi.reversado          := 'N';
               r_gmovi.emi_aviso          := 'N';
               r_gmovi.cod_mod_padre      := v_gar_list(i).cod_modulo;
               r_gmovi.cod_mad_padre      := v_gar_list(i).cod_modalidad;
               r_gmovi.cod_tra_padre      := 200;
               r_gmovi.cod_modulo         := v_gar_list(i).cod_modulo;
               r_gmovi.cod_modalidad      := v_gar_list(i).cod_modalidad;
               r_gmovi.protegido          := 'N';
               r_gmovi.cod_transaccion    := v_gar_list(i).cod_transaccion;
               r_gmovi.concepto           := 'CONSTITUCION GARANTIA(' || CASE WHEN v_gar_list(i).clasificacion = 'COMPUTABLE' THEN 'comp' ELSE 'nocomp' END || ')';
               r_gmovi.nro_documento      := v_gar_list(i).nro_garantia;
               r_gmovi.cod_persona        := v_gar_list(i).cod_persona;
               r_gmovi.referencia         := v_gar_list(i).cod_garantia;

               v_ins_mov(v_ins_mov.COUNT + 1) := r_gmovi;
            END IF;
         END LOOP;

         IF v_ins_mov.COUNT > 0 THEN
            FORALL i IN 1..v_ins_mov.COUNT
               INSERT INTO ge_movimientos (
                  nro_secuencia, fecha, hora, cod_usuario, fec_valor,
                  nro_cuenta, cod_moneda, cod_oficina, cod_ofi_origen, estado,
                  reversado, emi_aviso, cod_mod_padre, cod_mad_padre, cod_tra_padre,
                  cod_modulo, cod_modalidad, protegido, cod_transaccion, concepto,
                  nro_documento, cod_persona, referencia, monto, mto_equ_local, nro_documento2
               ) VALUES (
                  v_ins_mov(i).nro_secuencia, v_ins_mov(i).fecha, v_ins_mov(i).hora, v_ins_mov(i).cod_usuario, v_ins_mov(i).fec_valor,
                  v_ins_mov(i).nro_cuenta, v_ins_mov(i).cod_moneda, v_ins_mov(i).cod_oficina, v_ins_mov(i).cod_ofi_origen, v_ins_mov(i).estado,
                  v_ins_mov(i).reversado, v_ins_mov(i).emi_aviso, v_ins_mov(i).cod_mod_padre, v_ins_mov(i).cod_mad_padre, v_ins_mov(i).cod_tra_padre,
                  v_ins_mov(i).cod_modulo, v_ins_mov(i).cod_modalidad, v_ins_mov(i).protegido, v_ins_mov(i).cod_transaccion, v_ins_mov(i).concepto,
                  v_ins_mov(i).nro_documento, v_ins_mov(i).cod_persona, v_ins_mov(i).referencia, v_ins_mov(i).monto, v_ins_mov(i).mto_equ_local, v_ins_mov(i).nro_documento2
               );
         END IF;
      END LOOP;
      CLOSE c_garantias;

   EXCEPTION
      WHEN OTHERS THEN
         IF c_garantias%ISOPEN THEN
            CLOSE c_garantias;
         END IF;        
         raise_application_error(-20000, 'ERROR. PROCESAR GARANTIAS: ' || SQLERRM || 
                                         ' | Trace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
   END lp_gen_asi_procesar_garantias;

BEGIN
   -- Inicialización de variables generales
   v_fec_actual    := pag_cal.fu_obt_fec_actual(6);
   rv_gcale        := pag_cal.fu_obt_reg_cal(6);
   v_fec_anterior  := rv_gcale.fec_anterior;
   v_ofi_matriz    := fug_obt_ofi_matriz;

   BEGIN
      SELECT COUNT(*)
        INTO v_can_user
        FROM ba_cod_referencias
       WHERE dominio     = 'USU_MOV_CIERRE'
         AND abreviatura = 'MOVCIERRE';   
   EXCEPTION
      WHEN OTHERS THEN
         v_can_user := 1;
   END;

   lp_gen_asi_desafectacion;
   lp_gen_asi_procesar_garantias;
   
END PRB_GEN_ASI_GARANTIAS;
