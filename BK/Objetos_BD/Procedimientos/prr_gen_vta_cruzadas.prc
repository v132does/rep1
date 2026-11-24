CREATE OR REPLACE PROCEDURE IT.prr_gen_vta_cruzadas IS

   v_dia NUMBER(2);
   v_mes NUMERIC(2);
   v_ano VARCHAR2(4);

   v_mon_local  ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_mon_fuerte ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_fuerte;

   rg_cr_vta_cru cr_vta_cruzadas%ROWTYPE;

   v_sal_tot_cc cr_vta_cruzadas.sal_tot_cc_gs%TYPE;

   v_deb_automatico NUMBER := 0;
   v_insertar       NUMBER(5) := 0;

   v_paso NUMBER := 0;

   v_cod_persona cr_vta_cruzadas.cod_persona%TYPE;

   v_abreviatura ba_cod_referencias.abreviatura%TYPE;

   -------------------------------------

   TYPE re_prod IS RECORD(
      nro_cuenta         cc_cta_corrientes.nro_cuenta%TYPE,
      cod_moneda         VARCHAR2(300),
      fecha_apertura     DATE,
      des_mad_tc         VARCHAR2(300),
      descripcion_estado VARCHAR2(300),
      saldo_total        VARCHAR2(300),
      sal_batch          NUMBER,
      sal_ret_batch      NUMBER,
      sal_blo_batch      NUMBER,
      cod_ente           NUMBER,
      cod_modulo         NUMBER,
      lin_credito        VARCHAR2(300),
      cod_persona        VARCHAR2(300),
      tip_producto       VARCHAR2(300),
      tip_cc             VARCHAR2(300));

   TYPE tprod IS TABLE OF re_prod INDEX BY BINARY_INTEGER;

   rprod tprod;

   -------------------------------------

   /*cursor que busca todos los clientes*/
   CURSOR clientes IS
      SELECT a.cod_persona,
             decode(b.tipo, 'J',
                    (SELECT c.raz_social FROM ba_per_juridicas c WHERE c.cod_persona = b.cod_persona),
                    b.nom_completo) nom_completo,
             b.tipo,
             b.cod_tip_documento,
             b.nro_documento,
             fue_obt_nom_usuario(a.cod_usu_oficial) nom_comercial,
             fue_obt_des_oficina(a.cod_oficina) des_oficina,
             a.cat_automatica,
             a.cat_sistema,
             a.val_comercial des_seg_cliente
        FROM ge_clientes a, ba_personas b
       WHERE a.cod_persona = b.cod_persona;

   -------------------------------------

   rcliente clientes%ROWTYPE;

   -------------------------------------

   /*cursor con los productos por cliente*/
   CURSOR productos IS
      SELECT prods.nro_cuenta,
             prods.cod_moneda,
             prods.fec_ape_cc    fecha_apertura,
             prods.des_mad_tc,
             prods.des_est_cc    descripcion_estado,
             prods.sal_tot_cc    saldo_total,
             prods.sal_batch,
             prods.sal_ret_batch,
             prods.sal_blo_batch,
             prods.cod_ente,
             prods.cod_modulo,
             prods.lin_credito,
             prods.cod_persona,
             prods.tip_producto,
             prods.tip_cc
        FROM (
              /*cta ctes sobregiro*/
              SELECT cc.nro_cuenta,
                      cc.cod_moneda,
                      cc.fec_apertura fec_ape_cc,
                      '-999' des_mad_tc,
                      fug_obt_des_est_cta(cc.cod_modulo, cc.cod_modalidad, cc.estado) des_est_cc,
                      to_char(abs(nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) -
                                  nvl(cc.sal_blo_batch, 0))) sal_tot_cc,
                      0 sal_batch,
                      0 sal_ret_batch,
                      0 sal_blo_batch,
                      cc.cod_ente,
                      cc.cod_modulo,
                      '-999' lin_credito,
                      c1.cod_persona,
                      'cc' tip_producto,
                      '0' tip_cc
                FROM ge_cta_clientes c1, cc_cta_corrientes cc
               WHERE c1.nro_cuenta = cc.nro_cuenta
                 AND c1.relacion = 'P'
                 AND (nvl(cc.sal_tot_batch, 0) <> 0 OR nvl(cc.sal_ret_batch, 0) <> 0 OR
                     nvl(cc.sal_blo_batch, 0) <> 0)
                 AND nvl(cc.sal_tot_batch, 0) - nvl(cc.sal_ret_batch, 0) - nvl(cc.sal_blo_batch, 0) < 0
              
              UNION ALL
              
              /*cheques certificados*/
              SELECT ch.nro_cuenta,
                     cc.cod_moneda,
                     cc.fec_apertura,
                     '-999',
                     fug_obt_des_est_cta(cc.cod_modulo, cc.cod_modalidad, cc.estado) des_est_cc,
                     to_char(nvl(ch.monto, 0)) sal_che,
                     0,
                     0,
                     0,
                     cc.cod_ente,
                     cc.cod_modulo,
                     '-999' lin_credito,
                     gc.cod_persona,
                     'cc' tip_producto,
                     '0' tip_cc
                FROM cc_che_certificados ch,
                     ge_cta_clientes     gc,
                     ge_clientes         c,
                     cc_cta_corrientes   cc,
                     cc_cta_bancarias    cb
               WHERE ch.nro_cuenta = gc.nro_cuenta
                 AND gc.cod_persona = c.cod_persona
                 AND cc.nro_cuenta = ch.nro_cuenta
                 AND ch.nro_cta_certificado = cb.nro_cuenta
                 AND ch.fec_pago IS NULL
                 AND gc.relacion = 'P'
              
              UNION ALL
              
              /*cta ctes*/
              SELECT cc2.nro_cuenta,
                     cc2.cod_moneda,
                     cc2.fec_apertura fec_ape_cc,
                     '-999' des_mad_tc,
                     fug_obt_des_est_cta(cc2.cod_modulo, cc2.cod_modalidad, cc2.estado) des_est_cc,
                     to_char(nvl(cc2.sal_tot_batch, 0) - nvl(cc2.sal_ret_batch, 0) -
                             nvl(cc2.sal_blo_batch, 0)) sal_tot_cc2,
                     nvl(cc2.sal_tot_batch, 0) sal_batch,
                     nvl(cc2.sal_ret_batch, 0) sal_ret_batch,
                     nvl(cc2.sal_blo_batch, 0) sal_blo_batch,
                     cc2.cod_ente,
                     cc2.cod_modulo,
                     '-999' lin_credito,
                     gc1.cod_persona,
                     'cc' tip_producto,
                     'cc' tip_cc
                FROM ge_cta_clientes gc1, cc_cta_corrientes cc2
               WHERE gc1.nro_cuenta = cc2.nro_cuenta
                 AND gc1.relacion = 'P'
                 AND (cc2.sal_tot_batch <> 0 OR cc2.sal_ret_batch <> 0 OR cc2.sal_blo_batch <> 0)
              
              UNION ALL
              
              /*cta ahorros*/
              SELECT ca.nro_cuenta,
                     ca.cod_moneda,
                     ca.fec_apertura fec_ape_av,
                     '-999' des_mad_tc,
                     fug_obt_des_est_cta(ca.cod_modulo, ca.cod_modalidad, ca.estado) des_est_av,
                     to_char(nvl(ca.sal_tot_batch, 0) - nvl(ca.sal_ret_batch, 0)) sal_tot_av,
                     0,
                     0,
                     0,
                     ca.cod_ente,
                     ca.cod_modulo,
                     '-999' lin_credito,
                     c2.cod_persona,
                     'ca' tip_producto,
                     '0'
                FROM ge_cta_clientes c2, ah_cta_vistas ca
               WHERE c2.nro_cuenta = ca.nro_cuenta
                 AND c2.relacion = 'P'
              
              UNION ALL
              
              /*cta certificados*/
              SELECT ccer.nro_cuenta,
                     ccer.cod_moneda,
                     ccer.fec_apertura,
                     '-999' des_mad_tc,
                     fug_obt_des_est_cta(ccer.cod_modulo, ccer.cod_modalidad, ccer.estado) des_est_cda,
                     to_char(nvl(ccer.sal_tot_batch, 0) - nvl(ccer.sal_ret_batch, 0)) sal_tot_cda,
                     0,
                     0,
                     0,
                     -999,
                     -999,
                     '-999' lin_credito,
                     c3.cod_persona,
                     'ccer' tip_producto,
                     '0'
                FROM ge_cta_clientes c3, ah_cta_certificados ccer
               WHERE c3.nro_cuenta = ccer.nro_cuenta
                 AND c3.relacion = 'P'
                 AND ccer.cod_modalidad != 36
                 AND ccer.estado NOT IN ('C', 'T')
              
              UNION ALL
              
              /*cta prestamos*/
              SELECT cp.nro_cuenta,
                     cp.cod_moneda,
                     cp.fec_inicio,
                     '-999' des_mad_tc,
                     fug_obt_des_modal(cp.cod_modulo, cp.cod_modalidad) des_mad_prestamo,
                     to_char(nvl(cp.sal_capital, 0)) sal_prestamo,
                     0,
                     0,
                     0,
                     -999,
                     -999,
                     '-999' lin_credito,
                     c4.cod_persona,
                     'cp' tip_producto,
                     '0'
                FROM ge_cta_clientes c4, pr_cta_prestamos cp
               WHERE c4.nro_cuenta = cp.nro_cuenta
                 AND c4.relacion = 'P'
                 AND cp.estado NOT IN ('N', 'I')
              
              UNION ALL
              
              /*cta tarjetas*/
              SELECT ct.nro_cuenta,
                     ct.cod_moneda,
                     ct.fec_apertura,
                     fug_obt_des_modal(ct.cod_modulo, ct.cod_modalidad) des_mad_tc,
                     fug_obt_des_est_cta(ct.cod_modulo, ct.cod_modalidad, ct.estado) des_est_tc,
                     to_char(nvl(ct.sal_procesadora, 0)) sal_tot_tc,
                     0,
                     0,
                     0,
                     -999,
                     -999,
                     to_char(nvl(ct.lin_credito, 0)) lin_credito,
                     c5.cod_persona,
                     'ct' tip_producto,
                     '0'
                FROM ge_cta_clientes c5, ta_cta_tarjetas ct
               WHERE c5.nro_cuenta = ct.nro_cuenta
                 AND c5.relacion = 'P'
                 AND ct.estado <> 'C'
                 AND ct.cod_modalidad <> 55
              
              UNION ALL
              
              /*linea sobregiro*/
              SELECT ls.nro_cuenta,
                     ls.cod_moneda,
                     SYSDATE,
                     '-999',
                     '-999',
                     to_char(nvl(ls.monto, 0)) monto,
                     0,
                     0,
                     0,
                     -999,
                     -999,
                     '-999',
                     ls.cod_persona,
                     'ls' tip_producto,
                     '0'
                FROM cc_lin_sobregiros ls
              
              UNION ALL
              
              /*cta tarjeta tmp*/
              SELECT ctt.nro_cuenta,
                     '-999',
                     ctt.fec_solicitud,
                     fug_obt_des_modal(ct2.cod_modulo, ct2.cod_modalidad) des_mad_tc,
                     '-999',
                     '0',
                     0,
                     0,
                     0,
                     -999,
                     -999,
                     '-999',
                     c6.cod_persona,
                     'ctt',
                     '0'
                FROM ge_cta_clientes c6, ta_tarjetas_tmp ctt, ta_cta_tarjetas ct2
               WHERE c6.nro_cuenta = ctt.nro_cuenta
                 AND ctt.nro_cuenta = ct2.nro_cuenta
                 AND ctt.relacion = 1
              
              UNION ALL
              
              /*cta tarjeta debito*/
              SELECT cd.nro_cuenta,
                     '-999',
                     cd.fec_ingreso,
                     '-999',
                     '-999',
                     '-999',
                     0,
                     0,
                     0,
                     -999,
                     -999,
                     '-999',
                     cd.cod_persona,
                     'cd',
                     '0'
                FROM ah_tar_debitos cd) prods
      
       WHERE prods.cod_persona = v_cod_persona
       ORDER BY prods.tip_producto, prods.fec_ape_cc ASC;

   -------------------------------------

   FUNCTION fp_existe_vta_cruzadas RETURN BOOLEAN IS
      v_existe NUMBER := 0;
   
   BEGIN
   
      SELECT 1
        INTO v_existe
        FROM cr_vta_cruzadas a
       WHERE a.ano = v_ano
         AND a.mes = v_mes
         AND a.dia = v_dia
         AND rownum = 1;
      RETURN TRUE;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN FALSE;
      WHEN too_many_rows THEN
         RETURN TRUE;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error en fp_existe_vta_cruzadas ' || SQLERRM);
   END;

   -------------------------------------

   FUNCTION fp_calcula_saldo_cta_cte
   (
      v_sal_tot_batch IN NUMBER,
      v_sal_ret_batch IN NUMBER,
      v_sal_blo_batch IN NUMBER
   ) RETURN NUMBER IS
      v_sal_disponible NUMBER;
      v_sal_contable   NUMBER;
   BEGIN
      v_sal_disponible := v_sal_tot_batch - v_sal_ret_batch - v_sal_blo_batch;
   
      CASE
         WHEN v_sal_disponible > 0 AND v_sal_blo_batch = 0 THEN
            v_sal_contable := v_sal_disponible;
         WHEN v_sal_disponible > 0 AND v_sal_blo_batch > 0 THEN
            v_sal_contable := v_sal_disponible + v_sal_blo_batch;
         WHEN v_sal_disponible < 0 AND v_sal_blo_batch > 0 THEN
            v_sal_contable := v_sal_blo_batch;
         WHEN v_sal_disponible = 0 AND v_sal_blo_batch > 0 THEN
            v_sal_contable := v_sal_blo_batch;
         WHEN v_sal_disponible < 0 AND v_sal_blo_batch = 0 THEN
            v_sal_contable := 0;
         WHEN v_sal_disponible = 0 AND v_sal_blo_batch = 0 THEN
            v_sal_contable := 0;
         ELSE
            v_sal_contable := 0;
      END CASE;
   
      RETURN v_sal_contable;
   END;

   -------------------------------------

BEGIN

   v_paso := 1;
   /*obtener dia,mes,año*/
   SELECT to_number(to_char(SYSDATE, 'DD')),
          to_number(to_char(SYSDATE, 'MM')),
          to_number(to_char(SYSDATE, 'YYYY'))
     INTO v_dia, v_mes, v_ano
     FROM dual;

   -------------------------------------

   v_paso := 2;
   /*borrar los datos del dia si existiera*/
   IF fp_existe_vta_cruzadas THEN
      BEGIN
         DELETE FROM cr_vta_cruzadas a
          WHERE a.ano = v_ano
            AND a.mes = v_mes
            AND a.dia = v_dia;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'error al borrar cr_vta_cruzadas ' || SQLERRM);
      END;
   END IF;

   -------------------------------------

   v_paso := 3;

   OPEN clientes;

   LOOP
      FETCH clientes
         INTO rcliente;
      EXIT WHEN clientes%NOTFOUND;
   
      v_cod_persona := rcliente.cod_persona;
   
      rg_cr_vta_cru.cli_nomina := 'N';
   
      IF rcliente.des_seg_cliente IS NOT NULL THEN
         v_abreviatura                 := fue_obt_des_refcodes('VAL_COMERCIAL',
                                                               rcliente.des_seg_cliente);
         rg_cr_vta_cru.des_seg_cliente := substr(v_abreviatura, 1, 35);
      END IF;
   
      -------------------------------------
   
      v_paso := 4;
   
      OPEN productos;
   
      LOOP
      
         rprod.delete;
      
         FETCH productos BULK COLLECT
            INTO rprod LIMIT 2000;
      
         EXIT WHEN rprod.first IS NULL;
      
         FOR i IN rprod.first .. rprod.last LOOP
         
            v_insertar := 1;
         
            -------------------------------------
         
            v_paso := 5;
            /*ctas ahorros*/
            IF rprod(i).tip_producto = 'ca' THEN
               IF rprod(i).cod_ente IS NOT NULL THEN
                  rg_cr_vta_cru.cli_nomina     := 'S';
                  rg_cr_vta_cru.des_ente       := fue_obt_nom_ente(rprod(i).cod_ente);
                  rg_cr_vta_cru.nro_cta_nomina := rprod(i).nro_cuenta;
                  rg_cr_vta_cru.tip_nomina     := 'CA';
               END IF;
            
               IF rprod(i).cod_moneda = v_mon_local THEN
                  IF rg_cr_vta_cru.fec_ape_av_gs IS NULL AND rg_cr_vta_cru.des_est_av_gs IS NULL AND
                     rg_cr_vta_cru.sal_tot_av_gs IS NULL THEN
                     rg_cr_vta_cru.fec_ape_av_gs := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_av_gs := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_av_gs := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.fec_ape_av_gs := rg_cr_vta_cru.fec_ape_av_gs || '#' ||
                                                    to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_av_gs := rg_cr_vta_cru.des_est_av_gs || '#' || rprod(i)
                                                   .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_av_gs := rg_cr_vta_cru.sal_tot_av_gs || '+' || rprod(i)
                                                   .saldo_total;
                  END IF;
               ELSIF rprod(i).cod_moneda = v_mon_fuerte THEN
                  IF rg_cr_vta_cru.fec_ape_av_usd IS NULL AND rg_cr_vta_cru.des_est_av_usd IS NULL AND
                     rg_cr_vta_cru.sal_tot_av_usd IS NULL THEN
                     rg_cr_vta_cru.fec_ape_av_usd := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_av_usd := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_av_usd := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.fec_ape_av_usd := rg_cr_vta_cru.fec_ape_av_usd || '#' ||
                                                     to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_av_usd := rg_cr_vta_cru.des_est_av_usd || '#' || rprod(i)
                                                    .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_av_usd := rg_cr_vta_cru.sal_tot_av_usd || '+' || rprod(i)
                                                    .saldo_total;
                  END IF;
               ELSIF rprod(i).cod_moneda = 'EUR' THEN
                  IF rg_cr_vta_cru.fec_ape_av_eur IS NULL AND rg_cr_vta_cru.des_est_av_eur IS NULL AND
                     rg_cr_vta_cru.sal_tot_av_eur IS NULL THEN
                     rg_cr_vta_cru.fec_ape_av_eur := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_av_eur := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_av_eur := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.fec_ape_av_eur := rg_cr_vta_cru.fec_ape_av_eur || '#' ||
                                                     to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_av_eur := rg_cr_vta_cru.des_est_av_eur || '#' || rprod(i)
                                                    .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_av_eur := rg_cr_vta_cru.sal_tot_av_eur || '+' || rprod(i)
                                                    .saldo_total;
                  END IF;
               END IF;
            END IF;
         
            -------------------------------------
         
            v_paso := 6;
            /*linea sobregiros*/
            IF rprod(i).tip_producto = 'ls' THEN
            
               IF rprod(i).cod_moneda = v_mon_local THEN
                  IF rg_cr_vta_cru.mto_lin_sob_gs IS NULL THEN
                     rg_cr_vta_cru.mto_lin_sob_gs := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.mto_lin_sob_gs := rg_cr_vta_cru.mto_lin_sob_gs || '+' || rprod(i)
                                                    .saldo_total;
                  END IF;
               ELSIF rprod(i).cod_moneda = v_mon_fuerte THEN
                  IF rg_cr_vta_cru.mto_lin_sob_usd IS NULL THEN
                     rg_cr_vta_cru.mto_lin_sob_usd := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.mto_lin_sob_usd := rg_cr_vta_cru.mto_lin_sob_usd || '+' || rprod(i)
                                                     .saldo_total;
                  END IF;
               ELSIF rprod(i).cod_moneda = 'EUR' THEN
                  IF rg_cr_vta_cru.mto_lin_sob_eur IS NULL THEN
                     rg_cr_vta_cru.mto_lin_sob_eur := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.mto_lin_sob_eur := rg_cr_vta_cru.mto_lin_sob_eur || '+' || rprod(i)
                                                     .saldo_total;
                  END IF;
               END IF;
            END IF;
         
            -------------------------------------
         
            v_paso := 7;
            /*ctas corrientes*/
            IF rprod(i).tip_producto = 'cc' THEN
               IF rprod(i).tip_cc = 'cc' THEN
                  IF rprod(i).cod_ente IS NOT NULL THEN
                     rg_cr_vta_cru.cli_nomina     := 'S';
                     rg_cr_vta_cru.des_ente       := fue_obt_nom_ente(rprod(i).cod_ente);
                     rg_cr_vta_cru.nro_cta_nomina := rprod(i).nro_cuenta;
                     rg_cr_vta_cru.tip_nomina     := 'CC';
                  END IF;
               END IF;
            
               IF rprod(i).tip_cc = 'cc' THEN
                  v_sal_tot_cc := to_char(fp_calcula_saldo_cta_cte(rprod(i).sal_batch,
                                                                   rprod(i).sal_ret_batch,
                                                                   rprod(i).sal_blo_batch));
               ELSE
                  v_sal_tot_cc := rprod(i).saldo_total;
               END IF;
            
               IF rprod(i).cod_moneda = v_mon_local THEN
                  IF rg_cr_vta_cru.fec_ape_cc_gs IS NULL AND rg_cr_vta_cru.des_est_cc_gs IS NULL AND
                     rg_cr_vta_cru.sal_tot_cc_gs IS NULL THEN
                     rg_cr_vta_cru.fec_ape_cc_gs := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cc_gs := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cc_gs := '+' || v_sal_tot_cc;
                  ELSE
                     rg_cr_vta_cru.fec_ape_cc_gs := rg_cr_vta_cru.fec_ape_cc_gs || '#' ||
                                                    to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cc_gs := rg_cr_vta_cru.des_est_cc_gs || '#' || rprod(i)
                                                   .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cc_gs := rg_cr_vta_cru.sal_tot_cc_gs || '+' ||
                                                    v_sal_tot_cc;
                  END IF;
               
               ELSIF rprod(i).cod_moneda = v_mon_fuerte THEN
                  IF rg_cr_vta_cru.fec_ape_cc_usd IS NULL AND rg_cr_vta_cru.des_est_cc_usd IS NULL AND
                     rg_cr_vta_cru.sal_tot_cc_usd IS NULL THEN
                     rg_cr_vta_cru.fec_ape_cc_usd := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cc_usd := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cc_usd := '+' || v_sal_tot_cc;
                  ELSE
                     rg_cr_vta_cru.fec_ape_cc_usd := rg_cr_vta_cru.fec_ape_cc_usd || '#' ||
                                                     to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cc_usd := rg_cr_vta_cru.des_est_cc_usd || '#' || rprod(i)
                                                    .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cc_usd := rg_cr_vta_cru.sal_tot_cc_usd || '+' ||
                                                     v_sal_tot_cc;
                  END IF;
               ELSIF rprod(i).cod_moneda = 'EUR' THEN
                  IF rg_cr_vta_cru.fec_ape_cc_eur IS NULL AND rg_cr_vta_cru.des_est_cc_eur IS NULL AND
                     rg_cr_vta_cru.sal_tot_cc_eur IS NULL THEN
                     rg_cr_vta_cru.fec_ape_cc_eur := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cc_eur := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cc_eur := '+' || v_sal_tot_cc;
                  ELSE
                     rg_cr_vta_cru.fec_ape_cc_eur := rg_cr_vta_cru.fec_ape_cc_eur || '#' ||
                                                     to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cc_eur := rg_cr_vta_cru.des_est_cc_eur || '#' || rprod(i)
                                                    .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cc_eur := rg_cr_vta_cru.sal_tot_cc_eur || '+' ||
                                                     v_sal_tot_cc;
                  END IF;
               END IF;
            END IF;
         
            -------------------------------------
         
            v_paso := 8;
            /*ctas certificados*/
            IF rprod(i).tip_producto = 'ccer' THEN
               IF rprod(i).cod_moneda = v_mon_local THEN
                  IF rg_cr_vta_cru.fec_ape_cda_gs IS NULL AND rg_cr_vta_cru.des_est_cda_gs IS NULL AND
                     rg_cr_vta_cru.sal_tot_cda_gs IS NULL THEN
                     rg_cr_vta_cru.fec_ape_cda_gs := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cda_gs := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cda_gs := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.fec_ape_cda_gs := rg_cr_vta_cru.fec_ape_cda_gs || '#' ||
                                                     to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cda_gs := rg_cr_vta_cru.des_est_cda_gs || '#' || rprod(i)
                                                    .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cda_gs := rg_cr_vta_cru.sal_tot_cda_gs || '+' || rprod(i)
                                                    .saldo_total;
                  END IF;
               ELSIF rprod(i).cod_moneda = v_mon_fuerte THEN
                  IF rg_cr_vta_cru.fec_ape_cda_usd IS NULL AND
                     rg_cr_vta_cru.des_est_cda_usd IS NULL AND
                     rg_cr_vta_cru.sal_tot_cda_usd IS NULL THEN
                     rg_cr_vta_cru.fec_ape_cda_usd := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cda_usd := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cda_usd := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.fec_ape_cda_usd := rg_cr_vta_cru.fec_ape_cda_usd || '#' ||
                                                      to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cda_usd := rg_cr_vta_cru.des_est_cda_usd || '#' || rprod(i)
                                                     .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cda_usd := rg_cr_vta_cru.sal_tot_cda_usd || '+' || rprod(i)
                                                     .saldo_total;
                  END IF;
               ELSIF rprod(i).cod_moneda = 'EUR' THEN
                  IF rg_cr_vta_cru.fec_ape_cda_eur IS NULL AND
                     rg_cr_vta_cru.des_est_cda_eur IS NULL AND
                     rg_cr_vta_cru.sal_tot_cda_eur IS NULL THEN
                     rg_cr_vta_cru.fec_ape_cda_eur := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cda_eur := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cda_eur := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.fec_ape_cda_eur := rg_cr_vta_cru.fec_ape_cda_eur || '#' ||
                                                      to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_est_cda_eur := rg_cr_vta_cru.des_est_cda_eur || '#' || rprod(i)
                                                     .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_cda_eur := rg_cr_vta_cru.sal_tot_cda_eur || '+' || rprod(i)
                                                     .saldo_total;
                  END IF;
               END IF;
            END IF;
         
            -------------------------------------
         
            v_paso := 9;
            /*ctas prestamos*/
            IF rprod(i).tip_producto = 'cp' THEN
               IF rprod(i).cod_moneda = v_mon_local THEN
                  IF rg_cr_vta_cru.fec_ini_pre_gs IS NULL AND rg_cr_vta_cru.des_mad_pre_gs IS NULL AND
                     rg_cr_vta_cru.sal_tot_pre_gs IS NULL THEN
                     rg_cr_vta_cru.fec_ini_pre_gs := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_mad_pre_gs := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_pre_gs := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.fec_ini_pre_gs := rg_cr_vta_cru.fec_ini_pre_gs || '#' ||
                                                     to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_mad_pre_gs := rg_cr_vta_cru.des_mad_pre_gs || '#' || rprod(i)
                                                    .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_pre_gs := rg_cr_vta_cru.sal_tot_pre_gs || '+' || rprod(i)
                                                    .saldo_total;
                  END IF;
               ELSIF rprod(i).cod_moneda = v_mon_fuerte THEN
                  IF rg_cr_vta_cru.fec_ini_pre_usd IS NULL AND
                     rg_cr_vta_cru.des_mad_pre_usd IS NULL AND
                     rg_cr_vta_cru.sal_tot_pre_usd IS NULL THEN
                     rg_cr_vta_cru.fec_ini_pre_usd := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_mad_pre_usd := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_pre_usd := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.fec_ini_pre_usd := rg_cr_vta_cru.fec_ini_pre_usd || '#' ||
                                                      to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_mad_pre_usd := rg_cr_vta_cru.des_mad_pre_usd || '#' || rprod(i)
                                                     .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_pre_usd := rg_cr_vta_cru.sal_tot_pre_usd || '+' || rprod(i)
                                                     .saldo_total;
                  END IF;
               ELSIF rprod(i).cod_moneda = 'EUR' THEN
                  IF rg_cr_vta_cru.fec_ini_pre_eur IS NULL AND
                     rg_cr_vta_cru.des_mad_pre_eur IS NULL AND
                     rg_cr_vta_cru.sal_tot_pre_eur IS NULL THEN
                     rg_cr_vta_cru.fec_ini_pre_eur := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_mad_pre_eur := rprod(i).descripcion_estado;
                     rg_cr_vta_cru.sal_tot_pre_eur := '+' || rprod(i).saldo_total;
                  ELSE
                     rg_cr_vta_cru.fec_ini_pre_eur := rg_cr_vta_cru.fec_ini_pre_eur || '#' ||
                                                      to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                     rg_cr_vta_cru.des_mad_pre_eur := rg_cr_vta_cru.des_mad_pre_eur || '#' || rprod(i)
                                                     .descripcion_estado;
                     rg_cr_vta_cru.sal_tot_pre_eur := rg_cr_vta_cru.sal_tot_pre_eur || '+' || rprod(i)
                                                     .saldo_total;
                  END IF;
               END IF;
            END IF;
         
            -------------------------------------
         
            v_paso := 10;
            /*ctas tarjetas*/
            IF rprod(i).tip_producto = 'ct' THEN
               IF rg_cr_vta_cru.fec_ape_tar_credito IS NULL AND
                  rg_cr_vta_cru.des_mad_tar_credito IS NULL AND
                  rg_cr_vta_cru.sal_tot_tar_credito IS NULL AND
                  rg_cr_vta_cru.des_est_tar_credito IS NULL AND rg_cr_vta_cru.lin_credito IS NULL THEN
                  rg_cr_vta_cru.fec_ape_tar_credito := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                  rg_cr_vta_cru.des_mad_tar_credito := rprod(i).des_mad_tc;
                  rg_cr_vta_cru.sal_tot_tar_credito := '+' || rprod(i).saldo_total;
                  rg_cr_vta_cru.des_est_tar_credito := rprod(i).descripcion_estado;
                  rg_cr_vta_cru.lin_credito         := '+' || rprod(i).lin_credito;
               ELSE
                  rg_cr_vta_cru.fec_ape_tar_credito := rg_cr_vta_cru.fec_ape_tar_credito || '#' ||
                                                       to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
                  rg_cr_vta_cru.des_mad_tar_credito := rg_cr_vta_cru.des_mad_tar_credito || '#' || rprod(i)
                                                      .des_mad_tc;
                  rg_cr_vta_cru.sal_tot_tar_credito := rg_cr_vta_cru.sal_tot_tar_credito || '+' || rprod(i)
                                                      .saldo_total;
                  rg_cr_vta_cru.des_est_tar_credito := rg_cr_vta_cru.des_est_tar_credito || '#' || rprod(i)
                                                      .descripcion_estado;
                  rg_cr_vta_cru.lin_credito         := rg_cr_vta_cru.lin_credito || '+' || rprod(i)
                                                      .lin_credito;
               END IF;
            END IF;
         
            -------------------------------------
         
            v_paso := 11;
            /*tarjetas temporal*/
            IF rprod(i).tip_producto = 'ctt' THEN
               IF rg_cr_vta_cru.fec_ape_adi_tar_credito IS NULL AND
                  rg_cr_vta_cru.des_mad_adi_tar_credito IS NULL AND
                  rg_cr_vta_cru.sal_tot_adi_tar_credito IS NULL THEN
                  rg_cr_vta_cru.fec_ape_adi_tar_credito := to_char(rprod(i).fecha_apertura,
                                                                   'dd/mm/yyyy');
                  rg_cr_vta_cru.des_mad_adi_tar_credito := rprod(i).des_mad_tc;
                  rg_cr_vta_cru.sal_tot_adi_tar_credito := '+' || rprod(i).saldo_total;
               ELSE
                  rg_cr_vta_cru.fec_ape_adi_tar_credito := rg_cr_vta_cru.fec_ape_adi_tar_credito || '#' ||
                                                           to_char(rprod(i).fecha_apertura,
                                                                   'dd/mm/yyyy');
                  rg_cr_vta_cru.des_mad_adi_tar_credito := rg_cr_vta_cru.des_mad_adi_tar_credito || '#' || rprod(i)
                                                          .des_mad_tc;
                  rg_cr_vta_cru.sal_tot_adi_tar_credito := rg_cr_vta_cru.sal_tot_adi_tar_credito || '+' || rprod(i)
                                                          .saldo_total;
               END IF;
            END IF;
         
            -------------------------------------
         
            v_paso := 12;
            /*tarjetas debito*/
            IF rprod(i).tip_producto = 'cd' THEN
               IF rg_cr_vta_cru.fec_ape_tar_debito IS NULL THEN
                  rg_cr_vta_cru.fec_ape_tar_debito := to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
               ELSE
                  rg_cr_vta_cru.fec_ape_tar_debito := rg_cr_vta_cru.fec_ape_tar_debito || '#' ||
                                                      to_char(rprod(i).fecha_apertura, 'dd/mm/yyyy');
               END IF;
            END IF;
         
         END LOOP;
      
      END LOOP;
   
      CLOSE productos;
   
      -------------------------------------
   
      v_paso := 13;
      /*busca debito automatico*/
      v_deb_automatico := 0;
      BEGIN
         SELECT COUNT(*)
           INTO v_deb_automatico
           FROM ge_cta_clientes c
          WHERE c.cod_persona = v_cod_persona
            AND EXISTS (SELECT 1
                   FROM ge_cob_ser_cuentas a
                  WHERE a.nro_cuenta = c.nro_cuenta
                    AND rownum = 1);
      EXCEPTION
         WHEN no_data_found THEN
            v_deb_automatico := 0;
      END;
   
      IF v_deb_automatico > 0 THEN
         rg_cr_vta_cru.deb_automatico := 'S';
      ELSE
         rg_cr_vta_cru.deb_automatico := 'N';
      END IF;
   
      -------------------------------------
   
      v_paso := 14;
      /*busca paquetes*/
      BEGIN
         SELECT a.fec_inicio fec_ape_paquete, fug_obt_paq_des_cliente(v_cod_persona) des_paquete
           INTO rg_cr_vta_cru.fec_ape_paquete, rg_cr_vta_cru.des_paquete
           FROM ge_paq_clientes a
          WHERE a.cod_persona = v_cod_persona
            AND a.estado = 'N';
      EXCEPTION
         WHEN no_data_found THEN
            rg_cr_vta_cru.fec_ape_paquete := NULL;
            rg_cr_vta_cru.des_paquete     := NULL;
         WHEN too_many_rows THEN
            rg_cr_vta_cru.fec_ape_paquete := NULL;
            rg_cr_vta_cru.des_paquete     := NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'error en ge_paq_clientes ' || SQLERRM);
      END;
   
      -------------------------------------
   
      v_paso := 15;
      /*consulta home banking*/
      rg_cr_vta_cru.cli_hom_banking := 'N';
      BEGIN
         SELECT /*+ index(b IN_BMOVI_COD_TIP_MENSAJE) +*/
          MIN(b.fec_hora) fec_ape_hb
           INTO rg_cr_vta_cru.fec_ape_hom_banking
           FROM bw_movimientos b
          WHERE b.cod_tip_mensaje = '005'
            AND b.cod_respuesta = '000'
            AND b.cod_per_ingreso = v_cod_persona;
         IF rg_cr_vta_cru.fec_ape_hom_banking IS NOT NULL THEN
            rg_cr_vta_cru.cli_hom_banking := 'S';
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'error en bw_movimientos ' || SQLERRM);
      END;
   
      -------------------------------------
   
      v_paso := 16;
      /*busca pago a proveedores*/
      BEGIN
         SELECT MIN(a.fec_insercion) fec_ape_pr
           INTO rg_cr_vta_cru.fec_ape_pag_salario
           FROM ge_entes a
          WHERE a.tipo = 'PR'
            AND a.cod_persona = v_cod_persona;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000, 'error en ge_entes ' || SQLERRM);
      END;
   
      -------------------------------------
   
      v_paso := 17;
      /*inserta registro por persona*/
   
      IF v_insertar = 1 THEN
      
         v_insertar := 0;
      
         INSERT INTO cr_vta_cruzadas
            (ano, mes, dia, cod_persona, nom_completo, tipo, cod_tip_documento, nro_documento,
             nom_comercial, des_oficina, cat_automatica, cat_sistema, des_seg_cliente, fec_ape_cc_gs,
             des_est_cc_gs, sal_tot_cc_gs, mto_lin_sob_gs, fec_ape_cc_usd, des_est_cc_usd,
             sal_tot_cc_usd, mto_lin_sob_usd, fec_ape_cc_eur, des_est_cc_eur, sal_tot_cc_eur,
             mto_lin_sob_eur, fec_ape_av_gs, des_est_av_gs, sal_tot_av_gs, fec_ape_av_usd,
             des_est_av_usd, sal_tot_av_usd, fec_ape_av_eur, des_est_av_eur, sal_tot_av_eur,
             fec_ape_cda_gs, des_est_cda_gs, sal_tot_cda_gs, fec_ape_cda_usd, des_est_cda_usd,
             sal_tot_cda_usd, fec_ape_cda_eur, des_est_cda_eur, sal_tot_cda_eur, fec_ini_pre_gs,
             des_mad_pre_gs, sal_tot_pre_gs, fec_ini_pre_usd, des_mad_pre_usd, sal_tot_pre_usd,
             fec_ini_pre_eur, des_mad_pre_eur, sal_tot_pre_eur, fec_ape_tar_credito,
             des_mad_tar_credito, sal_tot_tar_credito, des_est_tar_credito, lin_credito,
             fec_ape_adi_tar_credito, des_mad_adi_tar_credito, sal_tot_adi_tar_credito,
             fec_ape_tar_debito, deb_automatico, fec_ape_paquete, des_paquete, cli_nomina,
             mto_ult_sueldo, fec_ult_sueldo, des_ente, fec_ape_hom_banking, cli_hom_banking,
             fec_ape_pag_salario, nro_cta_nomina, tip_nomina)
         VALUES
         
            (v_ano, v_mes, v_dia, rcliente.cod_persona, rcliente.nom_completo, rcliente.tipo,
             rcliente.cod_tip_documento, rcliente.nro_documento, rcliente.nom_comercial,
             rcliente.des_oficina, rcliente.cat_automatica, rcliente.cat_sistema,
             rg_cr_vta_cru.des_seg_cliente,
             
             rg_cr_vta_cru.fec_ape_cc_gs, rg_cr_vta_cru.des_est_cc_gs,
             REPLACE(rg_cr_vta_cru.sal_tot_cc_gs, '.', ','),
             REPLACE(rg_cr_vta_cru.mto_lin_sob_gs, '.', ','), rg_cr_vta_cru.fec_ape_cc_usd,
             rg_cr_vta_cru.des_est_cc_usd, REPLACE(rg_cr_vta_cru.sal_tot_cc_usd, '.', ','),
             REPLACE(rg_cr_vta_cru.mto_lin_sob_usd, '.', ','), rg_cr_vta_cru.fec_ape_cc_eur,
             rg_cr_vta_cru.des_est_cc_eur, REPLACE(rg_cr_vta_cru.sal_tot_cc_eur, '.', ','),
             REPLACE(rg_cr_vta_cru.mto_lin_sob_eur, '.', ','), rg_cr_vta_cru.fec_ape_av_gs,
             rg_cr_vta_cru.des_est_av_gs, REPLACE(rg_cr_vta_cru.sal_tot_av_gs, '.', ','),
             rg_cr_vta_cru.fec_ape_av_usd, rg_cr_vta_cru.des_est_av_usd,
             REPLACE(rg_cr_vta_cru.sal_tot_av_usd, '.', ','), rg_cr_vta_cru.fec_ape_av_eur,
             rg_cr_vta_cru.des_est_av_eur, REPLACE(rg_cr_vta_cru.sal_tot_av_eur, '.', ','),
             rg_cr_vta_cru.fec_ape_cda_gs, rg_cr_vta_cru.des_est_cda_gs,
             REPLACE(rg_cr_vta_cru.sal_tot_cda_gs, '.', ','), rg_cr_vta_cru.fec_ape_cda_usd,
             rg_cr_vta_cru.des_est_cda_usd, REPLACE(rg_cr_vta_cru.sal_tot_cda_usd, '.', ','),
             rg_cr_vta_cru.fec_ape_cda_eur, rg_cr_vta_cru.des_est_cda_eur,
             REPLACE(rg_cr_vta_cru.sal_tot_cda_eur, '.', ','), rg_cr_vta_cru.fec_ini_pre_gs,
             rg_cr_vta_cru.des_mad_pre_gs, REPLACE(rg_cr_vta_cru.sal_tot_pre_gs, '.', ','),
             rg_cr_vta_cru.fec_ini_pre_usd, rg_cr_vta_cru.des_mad_pre_usd,
             REPLACE(rg_cr_vta_cru.sal_tot_pre_usd, '.', ','), rg_cr_vta_cru.fec_ini_pre_eur,
             rg_cr_vta_cru.des_mad_pre_eur, REPLACE(rg_cr_vta_cru.sal_tot_pre_eur, '.', ','),
             rg_cr_vta_cru.fec_ape_tar_credito, rg_cr_vta_cru.des_mad_tar_credito,
             REPLACE(rg_cr_vta_cru.sal_tot_tar_credito, '.', ','), rg_cr_vta_cru.des_est_tar_credito,
             REPLACE(rg_cr_vta_cru.lin_credito, '.', ','), rg_cr_vta_cru.fec_ape_adi_tar_credito,
             rg_cr_vta_cru.des_mad_adi_tar_credito,
             REPLACE(rg_cr_vta_cru.sal_tot_adi_tar_credito, '.', ','),
             rg_cr_vta_cru.fec_ape_tar_debito, rg_cr_vta_cru.deb_automatico,
             rg_cr_vta_cru.fec_ape_paquete, rg_cr_vta_cru.des_paquete, rg_cr_vta_cru.cli_nomina,
             rg_cr_vta_cru.mto_ult_sueldo, rg_cr_vta_cru.fec_ult_sueldo, rg_cr_vta_cru.des_ente,
             rg_cr_vta_cru.fec_ape_hom_banking, rg_cr_vta_cru.cli_hom_banking,
             rg_cr_vta_cru.fec_ape_pag_salario, rg_cr_vta_cru.nro_cta_nomina,
             rg_cr_vta_cru.tip_nomina);
      
         v_paso := 18;
      
      END IF;
   
      rg_cr_vta_cru := NULL;
      v_cod_persona := NULL;
   
   END LOOP;

   CLOSE clientes;

   -------------------------------------

   v_paso := 19;
   /*llama proceso de busqueda de salarios*/
   prr_gen_vta_cru_nominas;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,
                              'error en prr_gen_vta_cruzadas, ' || 'paso: ' || v_paso ||
                               ' persona: ' || v_cod_persona || ' error: ' || SQLERRM);
END;
/

