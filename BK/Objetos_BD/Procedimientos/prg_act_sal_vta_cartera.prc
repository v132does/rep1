CREATE OR REPLACE PROCEDURE IT.PRG_ACT_SAL_VTA_CARTERA is

  CURSOR c_sal_venta IS
    SELECT *
      FROM ge_sal_act_vta_cartera_tmp;
          
  v_fecha                   date;
  v_fec_actual              date := pag_cal.fu_obt_fec_actual(2);
  v_referencia              varchar2(100) := 'SAL_VTACARTERA';
  v_directorio              varchar2(100) := fug_obt_pardinamico('DIR_AUT_BANCARD');
  v_men_error               varchar2(200);
  v_ok                      varchar2(1) := 'N';
  v_can_dia_mora_ori        ge_sal_act_vta_cartera.can_dia_mora%type;
  v_cod_persona             ge_sal_inv_vta_cartera_his.cod_persona%type;
  v_nro_cuenta              ge_sal_inv_vta_cartera_his.nro_cuenta%type;
  v_mto_deuda_ori           ge_sal_inv_vta_cartera_his.mto_deuda%type;
  v_lugar                   varchar2(1000);
  v_cat_ope_actual          ge_sal_inv_vta_cartera_his.cat_ope_actual%type;
  v_can_dia_mora            ge_sal_inv_vta_cartera_his.dia_atr_actual%type;
  v_tot_ponderado           ge_sal_act_vta_cartera.saldo%type;     
  v_cat_ponderada           ge_sal_inv_vta_cartera_his.cat_cli_ponderada%type;     
  v_est_modulo              ba_modulos.estado%type;      
  
  CURSOR c_tot_clientes IS
    SELECT v.cod_persona, nvl(sum(v.saldo), 0) tot_saldo
      FROM ge_sal_act_vta_cartera v
     WHERE v.fec_saldo = v_fecha        
     GROUP BY v.cod_persona
    HAVING sum(nvl(v.saldo, 0)) > 0;
         
  CURSOR c_det_operaciones( p_cod_persona  ge_sal_act_vta_cartera.cod_persona%type ) IS
    SELECT d.saldo, s.cat_ope_actual
      FROM ge_sal_act_vta_cartera d, ge_sal_inv_vta_cartera_his s
     WHERE d.fec_saldo = v_fecha
       AND d.cod_persona = p_cod_persona
       AND d.nro_cuenta = s.nro_cuenta
       AND s.estado <> 'E'
       AND s.ope_recaptados = 'N'
     UNION
    SELECT d.saldo, s.cat_ope_actual
      FROM ge_sal_act_vta_cartera d, ge_sal_inv_vta_cartera_his s
     WHERE d.fec_saldo = v_fecha
       AND d.cod_persona = p_cod_persona
       AND '0'||d.nro_cuenta = s.nro_cuenta
       AND s.estado <> 'E'
       AND s.ope_recaptados = 'N';   
        
  FUNCTION fu_obt_cat_actual( p_can_dias     IN ge_sal_act_vta_cartera.can_dia_mora%type ) RETURN NUMBER IS
    v_cat_mora                ge_sal_inv_vta_cartera_his.dia_atr_actual%type := 1;
  BEGIN
    IF p_can_dias <= 0 THEN
      v_cat_mora := 1; --- riesgo normal    ---
    ELSIF p_can_dias <= 30 THEN
      v_cat_mora := 1.1; --- riesgo normal    ---
    ELSIF p_can_dias <= 60 THEN
      v_cat_mora := 1.2; --- riesgo normal    ---
    ELSIF p_can_dias <= 90 THEN
      v_cat_mora := 2; --- riesgo potencial ---
    ELSIF p_can_dias <= 150 THEN
      v_cat_mora := 3; --- riesgo real      ---
    ELSIF p_can_dias <= 180 THEN
      v_cat_mora := 4; --- alto riesgo      ---
    ELSIF p_can_dias <= 270 THEN
      v_cat_mora := 5; --- alto riesgo      ---
    ELSE
      v_cat_mora := 6; --- irrecuperable    ---
    END IF;  
    RETURN v_cat_mora;  
  END;
  
  PROCEDURE PR_INS_ASI_MANUALES(rp_bamde IN cb_asientos_det%ROWTYPE) 
  IS
  BEGIN
     -- Inserto en la cabecera.
     UPDATE cb_asientos cb
        SET cb.tot_control = cb.tot_control + rp_bamde.mto_mon_local
      WHERE cb.nro_asiento = rp_bamde.nro_asiento;
     
     IF SQL%NOTFOUND THEN
        
        INSERT INTO cb_asientos
           (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo, cod_modalidad, tot_control,
            actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado, fec_valor)
        VALUES
           (rp_bamde.cod_oficina, rp_bamde.nro_asiento, substr(user,1,10) , rp_bamde.fecha,
            2, 21, rp_bamde.mto_mon_local, 'N','N',rp_bamde.cod_oficina, 'N', 'S', rp_bamde.fecha);
     END IF;
     -- Inserto el detalle.
     INSERT INTO cb_asientos_det
        (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro,
         mto_mon_local, descripcion, referencia, protegido, actualizado, val_cotizacion,
         distribuido, ref_movimiento, fec_valor)
     VALUES
        (rp_bamde.fecha, rp_bamde.cod_oficina, rp_bamde.nro_asiento, rp_bamde.nro_linea,
         rp_bamde.cod_rubro, rp_bamde.tip_movimiento, rp_bamde.mto_mon_rubro,
         rp_bamde.mto_mon_local, rp_bamde.descripcion, rp_bamde.referencia, rp_bamde.protegido,
         rp_bamde.actualizado, rp_bamde.val_cotizacion, rp_bamde.distribuido,
         rp_bamde.ref_movimiento, rp_bamde.fec_valor);
  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20000,
                                'Ins.Cb_asientos_det ' || rp_bamde.nro_asiento || '-' ||
                                 rp_bamde.referencia || '-' || SQLERRM);
  END;  

FUNCTION FU_OBT_RUB_CONT(P_COD_MONEDA  IN GE_CUENTAS.COD_MONEDA%TYPE)
RETURN VARCHAR2
AS

v_rubro cb_rubros.cod_rubro%type;
BEGIN
   
                     select distinct g.cod_rubro 
                              into v_rubro
                              from ge_tip_asientos g, ge_transacciones c
                              where g.cod_tip_asiento=c.cod_tip_asiento
                              and c.cod_transaccion=8846
                              and g.tip_movimiento='C'
                              and g.cod_moneda=P_COD_MONEDA;
    
    RETURN v_rubro;
    
EXCEPTION
   WHEN OTHERS THEN
      v_rubro := 0;
      RETURN v_rubro;   
END;  
  
PROCEDURE pr_sal_reversado IS
      
      -- Variables.
      r_bamde               cb_asientos_det%ROWTYPE;
      v_mto_mon_local       cb_asientos_det.mto_mon_local%type;
      v_mto_mon_extranjera  cb_asientos_det.mto_mon_rubro%type;
      v_mto_cotizacion      cb_asientos_det.val_cotizacion%type;
      v_val_cotizacion      cb_asientos_det.val_cotizacion%type;
      v_referencia          cb_asientos_det.referencia%type;
      v_descripcion         cb_asientos_det.descripcion%type;
      v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;      
      v_fec_actual          cb_asientos_det.fecha%type := pag_cal.FU_OBT_FEC_ACTUAL(2); 
      v_fec_anterior        cb_asientos_det.fecha%type := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual,31,1);   
      v_cod_moneda          ba_monedas.cod_moneda%TYPE;
      v_cod_oficina         cb_asientos_det.cod_oficina%TYPE;
      v_nro_linea           ge_tip_asientos.nro_linea%TYPE;
      v_nro_asiento         cb_asientos.nro_asiento%type;
      v_tip_movimiento      cb_asientos_det.tip_movimiento%type;  
      v_tip_movimiento2      cb_asientos_det.tip_movimiento%type;            
            
       CURSOR c_sal_cont IS
        select x.* 
          from (select abs(sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)))mon_loc,
               abs(sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0)))mon_ext,
               a.cod_rubro,a.cod_oficina, g.cod_moneda
               from cb_sal_oficinas_dia a, cb_rubros g
               where a.fecha=v_fec_anterior
               and a.cod_rubro=g.cod_rubro
               and a.cod_rubro in(select distinct g.cod_rubro 
                                  from ge_tip_asientos g, ge_transacciones c
                                  where g.cod_tip_asiento=c.cod_tip_asiento
                                  and c.cod_transaccion=8846
                                  and g.tip_movimiento='D')
               group by a.cod_rubro,a.cod_oficina, g.cod_moneda) x
         where x.mon_loc > 0;
   --
   BEGIN
          
       v_nro_linea := 0;
       
      -- Genero los asientos contables.
      FOR reg IN c_sal_cont LOOP
         
         -- Asignacion de Valores.
         v_cod_moneda         := reg.cod_moneda;         
         v_mto_mon_local      := reg.mon_loc;
         v_mto_mon_extranjera := reg.mon_ext;
         v_cod_oficina        := reg.cod_oficina;
         
         -- Verifica la Moneda.
         IF v_cod_moneda = v_cod_mon_local THEN
            v_mto_mon_local      := v_mto_mon_local;
            v_mto_mon_extranjera := 0;
            v_mto_cotizacion     := 1;        
         ELSE            
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --
            v_mto_mon_local      := v_mto_mon_local;
            v_mto_mon_extranjera := v_mto_mon_extranjera;
         END IF;
         --         
         
            v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
            prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
            --
            
            v_tip_movimiento := 'C';
            
            v_referencia      := 'VTA_CARTERA';
            v_descripcion     := 'REV. VENTA CARTERA';
            
            -----
            
               v_nro_linea := v_nro_linea + 1;               
               --- Cargar registro de asientos detalles
               r_bamde.fecha          := v_fec_actual;
               r_bamde.cod_oficina    := reg.cod_oficina;
               r_bamde.nro_asiento    := v_nro_asiento;
               r_bamde.nro_linea      := v_nro_linea;
               r_bamde.cod_rubro      := reg.cod_rubro;
               r_bamde.tip_movimiento := v_tip_movimiento;
               r_bamde.mto_mon_rubro  := v_mto_mon_extranjera;
               r_bamde.mto_mon_local  := v_mto_mon_local;
               r_bamde.descripcion    := v_descripcion;
               r_bamde.referencia     := v_referencia;
               r_bamde.protegido      := 'N';
               r_bamde.actualizado    := 'N';
               r_bamde.val_cotizacion := v_val_cotizacion;
               r_bamde.distribuido    := 'N';
               r_bamde.ref_movimiento := NULL;
               
               pr_ins_asi_manuales(r_bamde);
               
               v_tip_movimiento2 := 'D';
               v_nro_linea := v_nro_linea + 1; 
               --- Cargar registro de asientos detalles de la contrapartida
               r_bamde.fecha          := v_fec_actual;
               r_bamde.cod_oficina    := reg.cod_oficina;
               r_bamde.nro_asiento    := v_nro_asiento;
               r_bamde.nro_linea      := v_nro_linea;
               r_bamde.cod_rubro      := FU_OBT_RUB_CONT(reg.cod_moneda);
               r_bamde.tip_movimiento := v_tip_movimiento2;
               r_bamde.mto_mon_rubro  := v_mto_mon_extranjera;
               r_bamde.mto_mon_local  := v_mto_mon_local;
               r_bamde.descripcion    := v_descripcion;
               r_bamde.referencia     := v_referencia;
               r_bamde.protegido      := 'N';
               r_bamde.actualizado    := 'N';
               r_bamde.val_cotizacion := v_val_cotizacion;
               r_bamde.distribuido    := 'N';
               r_bamde.ref_movimiento := NULL;
               
               pr_ins_asi_manuales(r_bamde);
               
                                         
       END LOOP;
   END;  
    
   PROCEDURE pr_sal_contables IS
      
      -- Variables.
      r_bamde               cb_asientos_det%ROWTYPE;
      v_mto_mon_local       cb_asientos_det.mto_mon_local%type;
      v_mto_mon_extranjera  cb_asientos_det.mto_mon_rubro%type;
      v_mto_cotizacion      cb_asientos_det.val_cotizacion%type;
      v_val_cotizacion      cb_asientos_det.val_cotizacion%type;
      v_referencia          cb_asientos_det.referencia%type;
      v_descripcion         cb_asientos_det.descripcion%type;
      v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;      
      v_fec_actual          cb_asientos_det.fecha%type := pag_cal.FU_OBT_FEC_ACTUAL(2);      
      v_mto_catera         cb_asientos_det.mto_mon_local%TYPE;
      v_cod_moneda          ba_monedas.cod_moneda%TYPE;
      v_cod_oficina         cb_asientos_det.cod_oficina%TYPE;
      v_nro_linea           ge_tip_asientos.nro_linea%TYPE;
      v_nro_asiento         cb_asientos.nro_asiento%type;
      v_existe              NUMBER;
      v_tip_movimiento      cb_asientos_det.tip_movimiento%type;
      v_tip_movimiento2      cb_asientos_det.tip_movimiento%type;     
      
              
      CURSOR c_sal_cartera IS
        SELECT sum(nvl(c.sal_deu_cta_actual,mto_deu_mon_cuenta)) sal_deu_cta_actual,c.cod_oficina,g.cod_moneda, pas_cri.fu_obt_cod_rubro(c.nro_cuenta, c.cod_modulo, c.cod_modalidad, 8846,
                                                                    g.cod_moneda, NULL, null,
                                                                    NULL, NULL, 'D', NULL, null) rubro,
           pas_cri.fu_obt_cod_rubro(c.nro_cuenta, c.cod_modulo, c.cod_modalidad, 8846,
                                                                    g.cod_moneda, NULL, null,
                                                                    NULL, NULL, 'C', NULL, null) rub_cont
           FROM ge_sal_inv_vta_cartera_his c, ge_cuentas g
          WHERE c.estado IN ( 'V', 'C' )
            AND c.ope_recaptados = 'N'
            and nvl(c.sal_deu_cta_actual,mto_deu_mon_cuenta) <> 0
            and g.nro_cuenta=c.nro_cuenta
            group by c.cod_oficina,g.cod_moneda, pas_cri.fu_obt_cod_rubro(c.nro_cuenta, c.cod_modulo, c.cod_modalidad, 8846,
                                                                    g.cod_moneda, NULL, null,
                                                                    NULL, NULL, 'D', NULL, null),
            pas_cri.fu_obt_cod_rubro(c.nro_cuenta, c.cod_modulo, c.cod_modalidad, 8846,
                                                                    g.cod_moneda, NULL, null,
                                                                    NULL, NULL, 'C', NULL, null);      
   --
   BEGIN
          
      SELECT COUNT(1)
        INTO v_existe
        FROM ge_sal_act_vta_cartera cb
       WHERE cb.fec_saldo = v_fecha;
   
      IF v_existe = 0 THEN
         raise_application_error(-20000,' ERROR. NO existen registros de venta de cartera en fecha: '||v_fecha);
      END IF;
      
      -- Reverso los asientos existentes.
      --pr_rev_dep_internos;
      v_nro_linea := 0;
      
      -- Genero los asientos contables.
      FOR reg IN c_sal_cartera LOOP
         
         -- Asignacion de Valores.
         v_cod_moneda         := reg.cod_moneda;         
         v_mto_catera         := reg.sal_deu_cta_actual;
         v_cod_oficina        := reg.cod_oficina;
         
         -- Verifica la Moneda.
         IF v_cod_moneda = v_cod_mon_local THEN
            v_mto_mon_local      := v_mto_catera;
            v_mto_mon_extranjera := 0;
            v_mto_cotizacion     := 1;        
         ELSE            
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --
            v_mto_mon_local      := round((v_mto_catera * v_mto_cotizacion),0);
            v_mto_mon_extranjera := v_mto_catera;
         END IF;
         --         
         
            v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
            prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
            --
            v_tip_movimiento := 'D';
            v_referencia      := 'VTA_CARTERA';
            v_descripcion     := 'SALDO VENTA DE CARTERA';
           
            -----
            
               v_nro_linea := v_nro_linea + 1;               
               --- Cargar registro de asientos detalles
               r_bamde.fecha          := v_fec_actual;
               r_bamde.cod_oficina    := reg.cod_oficina;
               r_bamde.nro_asiento    := v_nro_asiento;
               r_bamde.nro_linea      := v_nro_linea;
               r_bamde.cod_rubro      := reg.rubro;
               r_bamde.tip_movimiento := v_tip_movimiento;
               r_bamde.mto_mon_rubro  := v_mto_mon_extranjera;
               r_bamde.mto_mon_local  := v_mto_mon_local;
               r_bamde.descripcion    := v_descripcion;
               r_bamde.referencia     := v_referencia;
               r_bamde.protegido      := 'N';
               r_bamde.actualizado    := 'N';
               r_bamde.val_cotizacion := v_val_cotizacion;
               r_bamde.distribuido    := 'N';
               r_bamde.ref_movimiento := NULL;
               
               pr_ins_asi_manuales(r_bamde);
            ---Se inserta la contrapartida
            --v_nro_asiento2 := fug_obt_pardinamico('SIG_NRO_ASIENTO');
            --prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento2 + 1));
            --
            v_tip_movimiento2 := 'C';
            v_nro_linea := v_nro_linea + 1;               
               --- Cargar registro de asientos detalles
               r_bamde.fecha          := v_fec_actual;
               r_bamde.cod_oficina    := reg.cod_oficina;
               r_bamde.nro_asiento    := v_nro_asiento;
               r_bamde.nro_linea      := v_nro_linea;
               r_bamde.cod_rubro      := reg.rub_cont;
               r_bamde.tip_movimiento := v_tip_movimiento2;
               r_bamde.mto_mon_rubro  := v_mto_mon_extranjera;
               r_bamde.mto_mon_local  := v_mto_mon_local;
               r_bamde.descripcion    := v_descripcion;
               r_bamde.referencia     := v_referencia;
               r_bamde.protegido      := 'N';
               r_bamde.actualizado    := 'N';
               r_bamde.val_cotizacion := v_val_cotizacion;
               r_bamde.distribuido    := 'N';
               r_bamde.ref_movimiento := NULL;
               pr_ins_asi_manuales(r_bamde);
                                  
       END LOOP;
   END;

BEGIN
  BEGIN
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 2;
  END;
  --DYDMR-7486--Incidencia SAU - ITGF - Asientos Contables - Venta Carteras
  v_lugar := 'Estado del Modulo Contable'; 
  v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(2);
  if v_est_modulo <> 2 then
    v_men_error := 'Módulo no esta abierto. No podrá realizar proceso Venta de Cartera.';
    raise_application_error(-20001,'Módulo no esta abierto. No podrá realizar proceso Venta de Cartera');
  end if;
  
  v_fecha := last_day(v_fec_actual);
  v_lugar := 'Carga de datos de arhivo de Venta de Cartera';
  pag_arc.pr_arc_pro_archivo(v_referencia, v_directorio, v_fecha);
  v_lugar := 'Eliminación de registros anteriores de tabla de saldos actualizados';
  DELETE FROM ge_sal_act_vta_cartera v WHERE v.fec_saldo = v_fecha;
  DELETE FROM cb_asientos v WHERE v.fecha = v_fec_actual and  v.nro_asiento in (select t.nro_asiento FROM cb_asientos_det t WHERE t.fecha = v_fec_actual and t.referencia='VTA_CARTERA');
  DELETE FROM cb_asientos_det v WHERE v.fecha = v_fec_actual and v.referencia='VTA_CARTERA';
  v_lugar := 'Inicio de proceso de actualización';
  FOR s IN c_sal_venta LOOP
      v_men_error := null;
      v_nro_cuenta := s.nro_cuenta;
      -- Verifica que la cuenta a actualizar exista como operación vendida
      BEGIN
        SELECT 'S', h.mto_deuda, h.cod_persona
          INTO v_ok, v_mto_deuda_ori, v_cod_persona
          FROM ge_sal_inv_vta_cartera_his h
         WHERE h.nro_cuenta = v_nro_cuenta
           AND h.estado IN ( 'V', 'C' )
           AND h.ope_recaptados = 'N';
      EXCEPTION
        WHEN no_data_found THEN
          BEGIN
            SELECT 'S', h.mto_deuda, h.cod_persona, h.nro_cuenta
              INTO v_ok, v_mto_deuda_ori, v_cod_persona, v_nro_cuenta
              FROM ge_sal_inv_vta_cartera_his h
             WHERE h.nro_cuenta = '0'||v_nro_cuenta
               AND h.estado IN ( 'V', 'C' )
               AND h.ope_recaptados = 'N';
          EXCEPTION
            WHEN others THEN
              v_ok := 'N';
              v_mto_deuda_ori := 0;
              v_cod_persona := null;
          END;                     
        WHEN others THEN
          v_ok := 'N';
          v_mto_deuda_ori := 0;
          v_cod_persona := null;
      END;
      IF v_ok = 'N' THEN
         v_men_error := 'Cuenta no corresponde a una operación vendida o ya fue cancelada.';
      END IF;
      IF v_men_error IS NULL THEN
         BEGIN 
           SELECT v.can_dia_mora
             INTO v_can_dia_mora_ori
             FROM ge_sal_act_vta_cartera v
            WHERE v.nro_cuenta = s.nro_cuenta
              AND v.fec_saldo = ( SELECT max(a.fec_venta)
                                    FROM ge_sal_act_vta_cartera a
                                   WHERE a.nro_cuenta = s.nro_cuenta );
         EXCEPTION
           WHEN others THEN
             v_can_dia_mora_ori := 0;
         END;
         IF v_can_dia_mora_ori <> 0 THEN
            IF abs( v_can_dia_mora_ori - s.can_dia_mora ) > 31 THEN
               v_men_error := 'Los días de atraso no son consistentes en relación al último mes informado.';
            END IF;
         END IF;
         IF v_men_error IS NULL THEN
            IF v_mto_deuda_ori > 0 THEN
               IF v_mto_deuda_ori < s.saldo THEN
                  v_men_error := 'El saldo de la cuenta es mayor al monto de la deuda original.';
               END IF;   
            END IF;     
         END IF;   
      END IF; 
      v_lugar := 'Búsqueda de Cliente de Cuenta: '||s.nro_cuenta;
      IF v_cod_persona IS NULL THEN
         v_cod_persona := fug_obt_cli_principal(v_nro_cuenta, 'P');
         IF v_cod_persona IS NULL THEN
            v_cod_persona := fug_obt_cli_principal('0'||v_nro_cuenta, 'P');
         END IF;     
      END IF;
      v_lugar := 'Inserción de Saldos Actualizados. - Cuenta: '||s.nro_cuenta;
      BEGIN
        INSERT INTO ge_sal_act_vta_cartera ( nro_cuenta, 
                                             cod_persona,
                                             fec_saldo, 
                                             fec_venta, 
                                             can_dia_mora, 
                                             saldo, 
                                             estado, 
                                             error )
                                     VALUES( s.nro_cuenta,
                                             v_cod_persona, 
                                             v_fecha, 
                                             s.fec_venta, 
                                             s.can_dia_mora, 
                                             s.saldo, 
                                             decode( v_men_error, NULL, 'P', 'E' ), 
                                             v_men_error );
       END; 
       v_lugar := 'Obtención de categoría por día de atraso cuenta: '||s.nro_cuenta;
       IF nvl(s.saldo, 0) > 0 THEN
          v_cat_ope_actual := fu_obt_cat_actual( s.can_dia_mora );
          v_can_dia_mora   := s.can_dia_mora;
       ELSE
          v_cat_ope_actual := 1;
          v_can_dia_mora   := 0;  
       END IF;
       v_lugar := 'Actualización de categoría y saldo de cuenta: '||s.nro_cuenta;
       BEGIN
         UPDATE ge_sal_inv_vta_cartera_his h
            SET h.dia_atr_actual     = v_can_dia_mora,
                h.cat_ope_actual     = v_cat_ope_actual,
                h.estado             = decode(nvl(s.saldo, 0), 0, 'N', h.estado),
                h.sal_deu_cta_actual = nvl(s.saldo, 0) --DYDMR-7681-Incidencia SAU - ITGF - Incidencia Proceso Venta Cartera
          WHERE h.nro_cuenta = v_nro_cuenta
            AND h.estado <> 'E'
            AND h.ope_recaptados = 'N';           
       END;                                                                                                                                                                                          
   END LOOP; 
   FOR t IN c_tot_clientes LOOP
       v_tot_ponderado := 0;
       v_cat_ponderada := NULL;
       v_lugar := 'Ponderar deuda. Persona: '||t.cod_persona;
       FOR d IN c_det_operaciones( t.cod_persona ) LOOP
           v_tot_ponderado := v_tot_ponderado +
                              ((nvl(d.saldo, 0)) * round(nvl(d.cat_ope_actual,1)));                                
       END LOOP;
       v_lugar := 'Ponderar categoría: '||t.cod_persona;
       v_cat_ponderada :=  round( trunc ( ( v_tot_ponderado /
                                            ( nvl( t.tot_saldo, 0 ) ) ), 2 ), 0 );
       v_lugar := 'Actualización de categoría ponderada. Persona: '||t.cod_persona;
       BEGIN
         UPDATE ge_sal_inv_vta_cartera_his h
            SET h.cat_cli_ponderada = v_cat_ponderada
          WHERE h.cod_persona = t.cod_persona
            AND h.estado <> 'E'
            AND h.ope_recaptados = 'N';
       END;
   END LOOP; 
   v_lugar:='REVERSO CONTABLE';
   pr_sal_reversado;--reversa asientos anteriores
   v_lugar:='GENERACION CONTABLE';
   pr_sal_contables;---genera asientos actuales                            
EXCEPTION
  WHEN others THEN
    raise_application_error( -20000, 'Error en '||v_lugar||' '||sqlerrm);
END;
/

