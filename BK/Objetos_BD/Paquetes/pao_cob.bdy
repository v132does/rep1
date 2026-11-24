CREATE OR REPLACE PACKAGE BODY IT.pao_cob IS

   PROCEDURE pr_gen_preventivas IS
     CURSOR c_rcyo IS
     select * from ov_rcyo rcyo
     order by rcyo.cod_modulo, rcyo.cod_modalidad, rcyo.cod_oficina;

     CURSOR c_cuot(p_nro_cuenta pr_cuotas.nro_cuenta%type) IS
     select nvl(a.mto_capital, 0) + nvl(a.mto_interes, 0) mto_cuota,
            a.fec_vencimiento, a.fec_ult_pago, a.nro_cuota
       from pr_cuotas a
      where a.nro_cuenta = p_nro_cuenta
        and nvl(a.estado, 'x') <> 'N'
        and nvl(a.nro_cuota, 0) > 0
        and a.fec_vencimiento <= fuo_fec_strategy
    order by a.nro_cuota;
     --
     v_fec_actual    date;
     v_cod_modulo    ge_cuentas.cod_modulo%type;
     v_cod_modalidad ge_cuentas.cod_modalidad%type;
     v_cod_moneda    ge_cuentas.cod_moneda%type;
     v_cod_persona   ba_personas.cod_persona%type;
     v_cod_usu_of    ge_clientes.cod_usu_oficial%type;
     v_nom_completo  ba_personas.nom_completo%type;
     v_tipo          ba_personas.tipo%type;
     v_cod_tip_doc   ba_personas.cod_tip_documento%Type;
     v_nro_documento ba_personas.nro_documento%type;
     v_cod_pais      ba_personas.cod_pais%type;
     v_pri_nombre    varchar2(120);
     v_seg_nombre    ba_per_fisicas.seg_nombre%type;
     v_pri_apellido  ba_per_fisicas.pri_apellido%type;
     v_seg_apellido  ba_per_fisicas.seg_apellido%type;
     v_ape_casada    ba_per_fisicas.pri_apellido%type;
     v_dir_par       ba_direcciones.direccion%TYPE;
     v_dir_lab       ba_direcciones.direccion%TYPE;
     v_dir_lab_alt   ba_direcciones.direccion%TYPE;
     v_tel_par       VARCHAR2(20);
     v_tel_lab       VARCHAR2(20);
     v_tel_lab_alt   varchar2(20);
     v_can_cuotas    number;
     v_pri_cuo_atr   number;
     v_can_cuo_atr   number;
     v_pri_fec_ven   date;
     v_sal_cuo_mora  number;
     v_tip_inf_ope   number(1);
     v_mto_cuota     number;
     v_fec_vencimiento date;
     v_fec_ult_pago  date;
     v_tip_inf_gar   number;
     v_observacion   varchar2(100);
     v_tip_moneda    varchar2(1);
     v_mto_pago      number;
     v_nro_cuota     number;
     v_nro_tarjeta   ta_tarjetas.nro_tarjeta%type;
     v_dia_atraso    number;
     v_nro_cta_nva   ov_cta_vencidas.nro_cuenta%type;
     v_cod_sec_cre   pr_cta_prestamos.cod_sec_credito%type;
     v_nro_cuenta    ge_cuentas.nro_cuenta%type;
     v_regpr         pr_cta_prestamos%rowtype;

   BEGIN
     v_fec_actual := fuo_fec_strategy;
     FOR k IN c_rcyo LOOP
       v_nro_cuenta  := k.nro_cuenta;
       v_tip_inf_ope := null;
       v_nro_tarjeta := null;
       v_dia_atraso  := null;
       v_nro_cta_nva := null;
       v_cod_sec_cre := null;
       v_sal_cuo_mora := null;
       v_nro_cuota   := 0;

       if k.cod_modulo = 6 then -- Préstamos
         v_observacion := 'INC-1.1';
       elsif k.cod_modulo = 5 then -- Tarjetas
         v_observacion := 'INC-1.2';
         begin
           select a.mto_mora, a.dia_mora
             into v_sal_cuo_mora, v_dia_atraso
             from ta_cta_tarjetas a
            where a.nro_cuenta = k.nro_cuenta;
         end;
       elsif k.cod_modulo = 15 and k.cod_modalidad = 152 then -- Sobregiros
         v_observacion := 'INC-1.3';
         begin
           select ov.dia_atraso, ov.nro_cuenta
             into v_dia_atraso, v_nro_cta_nva
             from ov_cta_vencidas ov
            where ov.nro_cta_origen = k.nro_cuenta;
         exception
           when no_data_found then
             v_dia_atraso := null;
           when others then
             v_dia_atraso := null;
         end;
       elsif k.cod_modulo = 15 and k.cod_modalidad = 151 then -- Tarjetas Vencidas
         v_observacion := 'INC-1.4';
         begin
           select ov.dia_atraso, ov.nro_cuenta
             into v_dia_atraso, v_nro_cta_nva
             from ov_cta_vencidas ov
            where ov.nro_cta_origen = k.nro_cuenta;
         exception
           when no_data_found then
             v_dia_atraso := null;
           when others then
             v_dia_atraso := null;
         end;
       else
         v_observacion := 'INC-1.6'; -- Cta. Cte.
         select a.mto_mora
           into v_sal_cuo_mora
           from cc_sobregiros_res a
          where a.nro_cuenta = k.nro_cuenta;
       end if;

       v_tip_inf_gar := fu_obt_garantia(k.nro_cuenta,k.cod_modulo,v_observacion);

       begin
         select b.cod_usu_oficial
           into v_cod_usu_of
           from ge_clientes b
          where b.cod_persona = k.cod_persona;
       end;
       v_cod_modulo := k.cod_modulo;
       v_cod_modalidad := k.cod_modalidad;
       if k.cod_modulo = 6 then
         pap_pre.pr_obt_dat_prestamo(k.nro_cuenta,v_regpr);
         v_cod_modalidad := v_regpr.cod_modalidad;
         v_cod_moneda    := v_regpr.cod_moneda;
       else
         pag_cta.pr_obt_cuenta(k.nro_cuenta);
         v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
         v_cod_moneda    := pag_cta.g_ctas.cod_moneda;
       end if;
       --
       v_ape_casada    := pao_mor.fu_obt_ape_casada(k.cod_persona);
       --
       pre_obt_direccion(k.cod_persona, v_dir_par, v_dir_lab, v_dir_lab_alt);
       pre_obt_telefono(k.cod_persona, v_tel_par, v_tel_lab, v_tel_lab_alt);
       --
       if v_cod_moneda = pag_gen.fu_obt_mon_local then
         v_tip_moneda := 'G';
       elsif v_cod_moneda = pag_gen.fu_obt_mon_fuerte then
         v_tip_moneda := 'D';
       else
         v_tip_moneda := substr(v_cod_moneda,1,1);
       end if;
       --
       begin
         select pe.nom_completo, pe.tipo, pe.cod_tip_documento,
                pe.nro_documento, pe.cod_pais
           into v_nom_completo, v_tipo, v_cod_tip_doc,
                v_nro_documento, v_cod_pais
           from ba_personas pe
          where pe.cod_persona = k.cod_persona;
       end;

       if v_tipo = 'F' then
         begin
           select pf.pri_nombre, pf.seg_nombre, pf.pri_apellido,
                  pf.seg_apellido
             into v_pri_nombre,  v_seg_nombre,  v_pri_apellido,
                  v_seg_apellido
             from ba_per_fisicas pf
            where pf.cod_persona = k.cod_persona;
         end;
       else
         begin
           select pj.raz_social
             into v_pri_nombre
             from ba_per_juridicas pj
            where pj.cod_persona = k.cod_persona;
         end;
       end if;
       --
       if k.cod_modulo = 6 then
         v_tip_inf_ope := 1;
         select pres.cod_sec_credito
           into v_cod_sec_cre
           from pr_cta_prestamos pres
          where pres.nro_cuenta = k.nro_cuenta;
          ---
         begin
           select count(1)
             into v_can_cuotas
             from pr_cuotas
            where fec_vencimiento < v_fec_actual
              and nro_cuenta = k.nro_cuenta;
         exception
           when no_data_found then
           v_can_cuotas := 0;
         end;
         --
         begin
           SELECT MIN(x.nro_cuota) pri_cuo_atr,
                  COUNT(*) can_cuo_atr,
                  MIN(x.fec_vencimiento) pri_fec_ven_atr,
                  SUM(nvl(x.sal_capital, 0) + nvl(x.sal_interes, 0) +
                      nvl(x.sal_int_documentado, 0)) sal_cuo_mora
             INTO v_pri_cuo_atr, v_can_cuo_atr, v_pri_fec_ven, v_sal_cuo_mora
             FROM pr_cuotas x
            WHERE x.nro_cuenta = k.nro_cuenta
              AND x.nro_cuota <> 0
              AND x.estado <> 'N'
                 /** No incluir las cuotas con menos de 60 días de atraso. **/
              AND x.fec_vencimiento + nvl(v_dia_atr_ini_pre_informconf, 0) <= v_fec_actual;
         exception
           when no_data_found then
             v_pri_cuo_atr  := null;
             v_can_cuo_atr  := null;
             v_pri_fec_ven  := null;
             v_sal_cuo_mora := null;
         end;
         --
       elsif k.cod_modulo = 5 then
         v_nro_tarjeta := nvl(fut_obt_nro_tarjeta(k.nro_cuenta),fut_obt_tar_nro(v_cod_persona,k.nro_cuenta));
       end if;
       --
       --
      if k.cod_modulo = 6 then
        for x in c_cuot(k.nro_cuenta) loop
           v_mto_cuota       := x.mto_cuota;
           v_fec_vencimiento := x.fec_vencimiento;
           v_fec_ult_pago    := x.fec_ult_pago;
           v_nro_cuota       := x.nro_cuota;
         begin
           SELECT ct.nro_cuota pri_cuo_atr,
                  ct.fec_vencimiento pri_fec_ven_atr,
                  nvl(ct.sal_capital, 0) + nvl(ct.sal_interes, 0) +
                      nvl(ct.sal_int_documentado, 0) sal_cuo_mora
             INTO v_pri_cuo_atr, v_pri_fec_ven, v_sal_cuo_mora
             FROM pr_cuotas ct
            WHERE ct.nro_cuenta = k.nro_cuenta
              AND ct.nro_cuota = x.nro_cuota
              AND ct.nro_cuota <> 0
              AND ct.estado <> 'N'
                 /** No incluir las cuotas con menos de 60 días de atraso. **/
              AND ct.fec_vencimiento + nvl(v_dia_atr_ini_pre_informconf, 0) <= v_fec_actual;
         exception
           when no_data_found then
             v_pri_cuo_atr  := null;
             v_can_cuo_atr  := null;
             v_pri_fec_ven  := null;
             v_sal_cuo_mora := null;
         end;
           v_mto_pago := fup_obt_mto_cobrado(k.nro_cuenta,v_nro_cuota,v_fec_ult_pago);

       insert into co_inf_cob_personas
          (cod_usu_gestion,     cod_persona,     nro_cuenta,        nro_cuota,
           cod_modulo,          cod_modalidad,   cod_moneda,        fec_ini_envio,
           nro_documento,       pri_nombre,      seg_nombre,        pri_apellido,
           --
           seg_apellido,        ape_casada,      dir_particular,    dir_laboral,
           dir_lab_alternativo, tel_particular,  tel_laboral,       tel_lab_alternativo,
           fec_operacion,       can_cuotas,      tip_inf_operacion, pri_cuo_atrasada,
           ---
           can_cuo_atrasada,    mto_cuota,       fec_vencimiento,   fec_ult_pago,
           tip_inf_garantia,    tip_inf_moneda,  mto_deuda,         fec_final,
           tip_inf_cobro,       mto_cobrado,     fec_cobro,         tip_inf_actualizacion,
           ----
           inf_periodicidad,    nro_tarjeta,     observacion,       dia_atraso,
           nro_cta_nueva,       cod_ori_modulo,  cod_ori_modalidad, cod_sec_credito)
        values
          (v_cod_usu_of,        k.cod_persona,   k.nro_cuenta,      v_nro_cuota,
           k.cod_modulo,        k.cod_modalidad, v_cod_moneda,      v_fec_actual,
           v_nro_documento,     v_pri_nombre,    v_seg_nombre,      v_pri_apellido,
           --
           v_seg_apellido,      v_ape_casada,    v_dir_par,         v_dir_lab,
           v_dir_lab_alt,       v_tel_par,       v_tel_lab,         null,
           v_fec_actual,        v_can_cuotas,    v_tip_inf_ope,     v_pri_cuo_atr,
           ---
           v_can_cuo_atr,       v_mto_cuota,     v_fec_vencimiento, v_fec_ult_pago,
           v_tip_inf_gar,       v_tip_moneda,    v_sal_cuo_mora,    null,
           null,                v_mto_pago,      v_fec_ult_pago,    null,
           ----
           null,                v_nro_tarjeta,   v_observacion,     v_dia_atraso,
           v_nro_cta_nva,       k.cod_modulo,    k.cod_modalidad,   v_cod_sec_cre
           );
      end loop;
      --

     else
        v_mto_cuota       := null;
        v_fec_vencimiento := null;
        v_fec_ult_pago    := null;
        v_nro_cuota       := 0;
        v_mto_pago        := 0;
        --
       insert into co_inf_cob_personas
          (cod_usu_gestion,     cod_persona,     nro_cuenta,        nro_cuota,
           cod_modulo,          cod_modalidad,   cod_moneda,        fec_ini_envio,
           nro_documento,       pri_nombre,      seg_nombre,        pri_apellido,
           --
           seg_apellido,        ape_casada,      dir_particular,    dir_laboral,
           dir_lab_alternativo, tel_particular,  tel_laboral,       tel_lab_alternativo,
           fec_operacion,       can_cuotas,      tip_inf_operacion, pri_cuo_atrasada,
           ---
           can_cuo_atrasada,    mto_cuota,       fec_vencimiento,   fec_ult_pago,
           tip_inf_garantia,    tip_inf_moneda,  mto_deuda,         fec_final,
           tip_inf_cobro,       mto_cobrado,     fec_cobro,         tip_inf_actualizacion,
           ----
           inf_periodicidad,    nro_tarjeta,     observacion,       dia_atraso,
           nro_cta_nueva,       cod_ori_modulo,  cod_ori_modalidad, cod_sec_credito)
        values
          (v_cod_usu_of,        k.cod_persona,   k.nro_cuenta,      v_nro_cuota,
           k.cod_modulo,        k.cod_modalidad, v_cod_moneda,      v_fec_actual,
           v_nro_documento,     v_pri_nombre,    v_seg_nombre,      v_pri_apellido,
           --
           v_seg_apellido,      v_ape_casada,    v_dir_par,         v_dir_lab,
           v_dir_lab_alt,       v_tel_par,       v_tel_lab,         null,
           v_fec_actual,        v_can_cuotas,    v_tip_inf_ope,     v_pri_cuo_atr,
           ---
           v_can_cuo_atr,       v_mto_cuota,     v_fec_vencimiento, v_fec_ult_pago,
           v_tip_inf_gar,       v_tip_moneda,    v_sal_cuo_mora,    null,
           null,                v_mto_pago,      v_fec_ult_pago,    null,
           ----
           null,                v_nro_tarjeta,   v_observacion,     v_dia_atraso,
           v_nro_cta_nva,       k.cod_modulo,    k.cod_modalidad,   v_cod_sec_cre
           );
     end if;
     END LOOP;
   EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20000,'Error en PR_GEN_PREVENTIVAS Cta: '||v_nro_cuenta||' -> '||sqlerrm);
   END;

   /** Informconf- Llama a pro_gen_inf_linea , inserta, hace update o borra de co_inf_cob_personas.**/
   PROCEDURE pr_gen_inf_arc_cob IS
      /**
      || EFECTUA      : Proceso encargado de generar los archivos para enviar a Informconf la
      ||                información necesaria para la Gestión de Cobros por cuentas.
      ||                A la fecha son 3 archivos que se envían: Inclusión, Modificación y Exclusión,
      ||                los cuales tienen el mismo formato entre sí.
      ||                Se generan 2 juegos de archivos, uno para cuentas con días de mora hasta 180 días,
      ||                y otro para los que tengan más de 180 días de mora.
      **/
      /** Definiciones de Informconf:
      · Cuando se paga una cuota se debe informar como Modificación con el campo tip_inf_actualizacion
        = 'P' que significa pago. Si tenia varias cuotas en mora, y no pago todas, se debe volver a
        informar como Inclusión las cuotas que se deben seguir gestionando.
      · Si cae una nueva cuota en mora y el cliente ya se estaba informando, esta nueva cuota se informa
        como Modificación con el campo tip_inf_actualizacion = "D" (esto significa actualizar la deuda).
      · Se informa como Inclusión por el monto de pago mínimo o saldo en mora (según el que sea mayor),
        cuando el cliente cae en mora. **/
      /************************* PROCEDIMIENTOS PRIVADOS *************************/
      FUNCTION lf_obt_garantia
      (
         p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
         p_cod_modulo  ge_cuentas.cod_modulo%TYPE,
         p_observacion VARCHAR2
      ) RETURN NUMBER;

      PROCEDURE lp_obt_pago
      (
         p_nro_cuenta   IN ge_cuentas.nro_cuenta%TYPE,
         p_nro_cuota    IN pr_cuotas.nro_cuota%TYPE,
         p_cod_modulo   IN ge_cuentas.cod_modulo%TYPE,
         p_tip_cobro    OUT VARCHAR2,
         p_fec_ult_pago OUT DATE,
         p_mto_ult_pago OUT NUMBER,
         p_tip_informe  IN VARCHAR2,
         p_can_cuotas   IN pr_cuotas.nro_cuota%TYPE
      );

      /**************************** VARIABLES LOCALES ****************************/
      v_dir_par     ba_direcciones.direccion%TYPE;
      v_dir_lab     ba_direcciones.direccion%TYPE;
      v_dir_lab_alt ba_direcciones.direccion%TYPE;
      v_tel_par     VARCHAR2(20);
      v_tel_lab     VARCHAR2(20);
      /** Fecha actual del Módulo de Cobranzas. **/
      c_fec_actual  CONSTANT DATE := fuo_fec_strategy;
      v_fec_control DATE;
      v_max_fecha   DATE;
      v_tel_lab_alt VARCHAR2(20);
      v_tip_cobro   VARCHAR2(1);
      v_fec_pago    DATE;
      v_mto_pago    NUMBER(18, 2);
      r_linea       co_inf_cob_personas%ROWTYPE;
      v_can_inf     NUMBER(20);
      v_can_sol     NUMBER(20);
      v_can_asignar NUMBER(20);
      v_old_nro_cta ge_cuentas.nro_cuenta%TYPE;
      v_old_nro_cuo NUMBER(5);
      v_fec_ult_env DATE;
      v_nro         VARCHAR2(50);
      v_regs        NUMBER;
      v_mensaje     VARCHAR2(2000);
      v_error EXCEPTION;
      v_existe      NUMBER;
      v_estado      VARCHAR2(1);
      v_nro_1       NUMBER(18);
      v_mto_pagado  NUMBER(18, 2);
      v_dias_atraso NUMBER(4);
      v_cantidad    NUMBER(4);

      /** Carga de Cursores. **/
      CURSOR inclusiones(p_nuevos VARCHAR2) IS
      /** Prestamos. **/
         SELECT DISTINCT p.cod_persona,
                         c.nro_cuenta,
                         substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                         c.cod_modulo,
                         substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                         substr(f.seg_nombre, 1, 15) seg_nombre,
                         substr(f.pri_apellido, 1, 20) pri_apellido,
                         substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                           pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido),
                                1, 20) seg_apellido,
                         decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                         c.fec_inicio fec_operacion,
                         1 tip_operacion,
                         (SELECT MIN(pr.nro_cuota)
                            FROM pr_cuotas pr
                           WHERE pr.nro_cuenta = u.nro_cuenta
                             AND nvl(pr.nro_cuota, 0) > 0
                             AND nvl(pr.estado, 'x') <> 'N'
                             AND pr.fec_vencimiento <= c_fec_actual) nro_cuota,
                         c.can_cuotas,
                         decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                         (nvl(u.mto_capital, 0) + nvl(u.mto_interes, 0)) mto_cuota,
                         to_date(NULL, 'DD/MM/YYYY') fec_final,
                         NULL tip_actualizacion,
                         'M' periodicidad,
                         z.pri_cuo_atr pri_cuo_atrasada,
                         z.can_cuo_atr can_cuo_atrasada,
                         z.pri_fec_ven_atr pri_fec_ven_atrasada,
                         b.fec_ult_pago,
                         z.sal_cuo_mora sal_mora,
                         c.cod_modalidad,
                         c.cod_moneda,
                         'INC-1.1' observacion,
                         0 dias_atraso,
                         NULL nro_cta_nueva,
                         NULL cod_ori_modulo,
                         NULL cod_ori_modalidad,
                         c.cod_sec_credito
           FROM pr_cta_prestamos c,
                ge_cta_clientes t,
                ge_clientes l,
                ba_personas p,
                ba_per_fisicas f,
                ba_per_juridicas j,
                pr_cuotas u,
                ge_est_cuentas e,
                ge_par_dinamicos o,
                ge_cuentas w,
                (SELECT x.nro_cuenta nro_cta, MAX(x.fecha) fec_ult_pago
                   FROM pr_cobros x
                  WHERE x.fecha >= v_fec_ult_env
                    AND nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                        nvl(x.mto_int_documentado, 0) > 0
                  GROUP BY x.nro_cuenta) b,
                (SELECT x.nro_cuenta nro_cta,
                        MIN(x.nro_cuota) pri_cuo_atr,
                        COUNT(*) can_cuo_atr,
                        MIN(x.fec_vencimiento) pri_fec_ven_atr,
                        SUM(nvl(x.sal_capital, 0) + nvl(x.sal_interes, 0) +
                            nvl(x.sal_int_documentado, 0)) sal_cuo_mora
                   FROM pr_cuotas x
                  WHERE x.nro_cuenta IS NOT NULL
                    AND x.nro_cuota <> 0
                    AND x.estado <> 'N'
                       /** No incluir las cuotas con menos de 60 días de atraso. **/
                    AND x.fec_vencimiento + nvl(v_dia_atr_ini_pre_informconf, 0) <= c_fec_actual
                  GROUP BY x.nro_cuenta) z
          WHERE c.nro_cuenta = t.nro_cuenta
            AND t.nro_cuenta = w.nro_cuenta
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
            AND fug_es_empleado(l.cod_persona) = 'N'
            AND l.cod_persona = t.cod_persona
            AND nvl(t.relacion, 'x') = 'P'
            AND ((nvl(c.dia_atraso, 0) >= nvl(v_dia_atr_ini_pre_informconf, 0) AND
                l.cli_especial = 'N') OR
                (nvl(c.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                l.cli_especial = 'S'))
            AND l.cod_persona = p.cod_persona
            AND l.cod_persona = f.cod_persona(+)
            AND l.cod_persona = j.cod_persona(+)
            AND c.nro_cuenta = u.nro_cuenta
            AND nvl(u.nro_cuota, 0) > 0
            AND nvl(u.estado, 'x') <> 'N'
            AND u.fec_vencimiento <= c_fec_actual
            AND u.nro_cuenta = b.nro_cta(+)
            AND c.nro_cuenta = z.nro_cta
            AND nvl(z.sal_cuo_mora, 0) > v_sal_min_pre_cobranzas
            AND nvl(z.sal_cuo_mora, 0) <= v_sal_max_pre_cobranzas
            AND c.cod_modulo = e.cod_modulo
            AND c.cod_modalidad = e.cod_modalidad
            AND c.estado = e.estado
            AND e.activo = 'S'
            AND c.estado <> 'I'
               /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
               Debe ser nulo o Pertenecer a cualquier Banca, si se desea enviar mas
               bancas en un futuro se debe de incluir en el par_dinamico(TIP_BAN_INFORMCONF) ej.(1,2,3,...etc.) para el IN. **/
            AND l.cod_usu_oficial IN
                (SELECT cod_usuario
                   FROM ba_usuarios
                  WHERE oficial = 'S'
                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                        cod_banca IS NULL))
               /** Módulo y Modalidad a enviar(MOD_COBRANZA='S'). **/
            AND o.parametro = 'MOD_COBRANZAS'
            AND nvl(o.val_parametro, 'N') = 'S'
            AND o.cod_modulo = c.cod_modulo
            AND o.cod_modalidad = c.cod_modalidad
               --***************************
            AND NOT EXISTS (SELECT 1
                   FROM pr_cta_garantias x
                  WHERE x.nro_cuenta = c.nro_cuenta
                    AND x.cod_garantia = 5)
            AND NOT EXISTS (SELECT 1
                   FROM co_inf_cob_personas x
                  WHERE x.cod_persona = l.cod_persona
                    AND x.nro_cuenta = c.nro_cuenta)
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = l.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS
          (SELECT 1
                   FROM ge_tra_prohibidas z
                  WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND z.cod_modulo = c.cod_modulo
                    AND z.cod_modalidad = c.cod_modalidad
                    AND z.nro_cuenta = c.nro_cuenta)
               /** Para que excluya los que no se envian a informconf
               deben tener marcado env_informconf como 'N' EN BA_PER_DAT_ADICIONALES. **/
            AND p.cod_persona NOT IN (SELECT cod_persona
                                        FROM ba_per_dat_adicionales
                                       WHERE parametro LIKE 'ENV_INFORMCONF'
                                         AND nvl(val_parametro, 'S') = 'N')
         UNION ALL
         /** Tarjetas. **/
         SELECT p.cod_persona,
                c.nro_cuenta,
                substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                c.cod_modulo,
                substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                substr(f.seg_nombre, 1, 15) seg_nombre,
                substr(f.pri_apellido, 1, 20) pri_apellido,
                substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                  pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido), 1, 20) seg_apellido,
                decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                       substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                c.fec_apertura fec_operacion,
                3 tip_operacion,
                0 nro_cuota,
                NULL can_cuotas,
                decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1, nvl(c.mto_mora, 0),
                       /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                       nvl(c.mto_mora, 0),
                       /** Si el pago minimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                       nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)) mto_cuota,
                to_date(NULL, 'DD/MM/YYYY') fec_final,
                ' ' tip_actualizacion,
                'M' periodicidad,
                NULL pri_cuo_atrasada,
                1 can_cuo_atrasada,
                (c_fec_actual - nvl(c.dia_mora, 0)) pri_fec_ven_atrasada,
                MAX(b.fec_proceso) fec_ult_pago,
                decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1, nvl(c.mto_mora, 0),
                       /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                       nvl(c.mto_mora, 0),
                       /** Si el pago minimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                       nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)) sal_mora,
                c.cod_modalidad,
                c.cod_moneda,
                'INC-1.2' observacion,
                0 dias_atraso,
                NULL nro_cta_nueva,
                NULL cod_ori_modulo,
                NULL cod_ori_modalidad,
                NULL cod_sec_credito
           FROM ta_cta_tarjetas  c,
                ge_cta_clientes  t,
                ge_clientes      l,
                ba_personas      p,
                ba_per_fisicas   f,
                ba_per_juridicas j,
                ta_cobros        b,
                ge_est_cuentas   e,
                ge_par_dinamicos o,
                ge_cuentas       w
          WHERE c.nro_cuenta = t.nro_cuenta
            AND l.cod_persona = t.cod_persona
            AND nvl(t.relacion, 'x') = 'P'
            AND ((nvl(c.dia_mora, 0) >= nvl(v_dia_atr_ini_tar_informconf, 0) AND
                l.cli_especial = 'N') OR
                (nvl(c.dia_mora, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                l.cli_especial = 'S'))
            AND nvl(c.mto_mora, 0) > v_sal_min_tar_cob_informconf
            AND nvl(c.mto_mora, 0) <= v_sal_max_tar_cobranzas
            AND l.cod_persona = p.cod_persona
            AND l.cod_persona = f.cod_persona(+)
            AND l.cod_persona = j.cod_persona(+)
            AND c.nro_cuenta = b.nro_cuenta(+)
            AND nvl(b.fec_proceso(+), c_fec_actual) >= v_fec_ult_env
            AND c.cod_modulo = e.cod_modulo
            AND c.cod_modalidad = e.cod_modalidad
            AND c.estado = e.estado
            AND t.nro_cuenta = w.nro_cuenta
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
            AND fug_es_empleado(l.cod_persona) = 'N'
            AND e.activo = 'S'
            AND c.estado <> 'I'
            --AND nvl(c.en_juicio, 'N') = 'N' V.O. 17-10-13
               /** Por Módulo y Modalidad, por par_dinamico(MOD_COBRANZAS). **/
            AND o.parametro = 'MOD_COBRANZAS'
            AND nvl(o.val_parametro, 'N') = 'S'
            AND o.cod_modulo = c.cod_modulo
            AND o.cod_modalidad = c.cod_modalidad
               /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
               Debe ser nulo o Pertenecer a cualquier Banca. **/
            AND l.cod_usu_oficial IN
                (SELECT cod_usuario
                   FROM ba_usuarios
                  WHERE oficial = 'S'
                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                        cod_banca IS NULL))
               --***************************
            AND NOT EXISTS (SELECT 1
                   FROM co_inf_cob_personas x
                  WHERE x.cod_persona = l.cod_persona
                    AND x.nro_cuenta = c.nro_cuenta
                    AND x.nro_cuota = 0)
               /** No incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = l.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** No incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS
          (SELECT 1
                   FROM ge_tra_prohibidas z
                  WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND z.cod_modulo = c.cod_modulo
                    AND z.cod_modalidad = c.cod_modalidad
                    AND z.nro_cuenta = c.nro_cuenta)
               /** Para que excluya los que no se envian a informconf. **/
               /** Deben tener marcado env_informconf como 'N' EN BA_PER_DAT_ADICIONALES. **/
            AND p.cod_persona NOT IN (SELECT cod_persona
                                        FROM ba_per_dat_adicionales
                                       WHERE parametro LIKE 'ENV_INFORMCONF'
                                         AND val_parametro = 'N')
          GROUP BY p.cod_persona,
                   c.nro_cuenta,
                   substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15),
                   c.cod_modulo,
                   substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65),
                   substr(f.seg_nombre, 1, 15),
                   substr(f.pri_apellido, 1, 20),
                   substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                     pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido), 1,
                          20),
                   decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                          substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)),
                   c.fec_apertura,
                   3,
                   0,
                   NULL,
                   decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D'),
                   nvl(c.mto_pag_minimo, 0),
                   to_date(NULL, 'DD/MM/YYYY'),
                   ' ',
                   NULL,
                   NULL,
                   NULL,
                   (c_fec_actual - nvl(c.dia_mora, 0)),
                   decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1, nvl(c.mto_mora, 0),
                          /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                          nvl(c.mto_mora, 0),
                          /** Si el pago minimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                          nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)),
                   c.cod_modalidad,
                   c.cod_moneda
         /** Agregado para sobregiros.**/
         UNION ALL
         SELECT DISTINCT p.cod_persona,
                         m.nro_cta_origen nro_cuenta, --m.nro_cuenta,
                         substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                         4 cod_modulo,
                         substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                         substr(f.seg_nombre, 1, 15) seg_nombre,
                         substr(f.pri_apellido, 1, 20) pri_apellido,
                         substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                           pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido),
                                1, 20) seg_apellido,
                         decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                         (c_fec_actual - m.dia_atraso) fec_operacion,
                         4 tip_operacion,
                         0 nro_cuota,
                         NULL can_cuotas,
                         decode(nvl(w.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                         0 mto_cuota,
                         NULL fec_final,
                         ' ' tip_actualizacion,
                         'M' periodicidad,
                         NULL pri_cuo_atrasada,
                         1 can_cuo_atrasada,
                         NULL pri_fec_ven_atrasada,
                         NULL fec_ult_pago,
                         m.sal_total sal_mora,
                         41 cod_modalidad,
                         w.cod_moneda,
                         'INC-1.3' observacion,
                         m.dia_atraso dias_atraso,
                         m.nro_cuenta nro_cta_nueva,
                         15 cod_ori_modulo,
                         152 cod_ori_modalidad,
                         NULL cod_sec_credito
           FROM ov_cta_vencidas  m,
                ge_cta_clientes  t,
                ge_clientes      l,
                ba_personas      p,
                ba_per_fisicas   f,
                ba_per_juridicas j,
                ge_cuentas       w,
                ge_est_cuentas   e
          WHERE m.nro_cta_origen = t.nro_cuenta
            AND t.cod_persona = l.cod_persona
            AND l.cod_persona = p.cod_persona
            AND l.cod_persona = f.cod_persona(+)
            AND l.cod_persona = j.cod_persona(+)
            AND t.nro_cuenta = w.nro_cuenta
            AND w.cod_modulo = e.cod_modulo
            AND w.cod_modalidad = e.cod_modalidad
            AND m.cod_modulo = 15
            AND m.cod_modalidad = 152
            AND fug_es_empleado(l.cod_persona) = 'N'
            AND nvl(m.sal_total, 0) > nvl(v_sal_min_sob_cobranzas, 0)
            AND nvl(m.sal_total, 0) <= v_sal_max_sob_cobranzas
            AND nvl(m.dia_atraso, 0) >= v_dia_atr_ini_pre_informconf
            AND nvl(t.relacion, 'x') = 'P'
            AND m.estado <> 'C'
               --*****************************************************************
               /** No debe enviar los que ya fueron enviados en CC_CTA_CORRIENTES. **/
            AND NOT EXISTS
          (SELECT 1
                   FROM co_inf_cob_diarios f
                  WHERE f.nro_cuenta = m.nro_cta_origen
                    AND f.cod_modulo = 4
                    AND f.cod_modalidad = 41
                    AND f.fec_envio < c_fec_actual)
               /** Para parametro de mto_mora. **/
            AND ((nvl(m.dia_atraso, 0) >= nvl(v_dia_atr_ini_tar_informconf, 0) AND
                l.cli_especial = 'N') OR
                (nvl(m.dia_atraso, 0) >= nvl(v_dia_atr_ini_sob_informconf, 0) AND
                l.cli_especial = 'S'))
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
            AND e.activo = 'S'
               /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
               Debe ser nulo o Pertenecer a cualquier Banca. **/
            AND l.cod_usu_oficial IN
                (SELECT cod_usuario
                   FROM ba_usuarios
                  WHERE oficial = 'S'
                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                        cod_banca IS NULL))
            AND NOT EXISTS (SELECT 1
                   FROM co_inf_cob_personas s
                  WHERE s.cod_persona = l.cod_persona
                    AND s.nro_cuenta = m.nro_cta_origen
                    AND s.nro_cuota = 0)
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS
          (SELECT 1
                   FROM ge_tra_prohibidas z
                  WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND z.cod_modulo = w.cod_modulo
                    AND z.cod_modalidad = w.cod_modalidad
                    AND z.nro_cuenta = w.nro_cuenta)
               /** Para que excluya los que no se envian a informconf. **/
            AND p.cod_persona NOT IN (SELECT cod_persona
                                        FROM ba_per_dat_adicionales
                                       WHERE parametro LIKE 'ENV_INFORMCONF'
                                         AND val_parametro = 'N')
               /** No incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = l.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** No incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
         UNION ALL
         /** Agregado para Tarjetas Vencidas. **/
         SELECT DISTINCT p.cod_persona,
                         s.nro_cta_origen nro_cuenta, ---s.nro_cuenta,
                         substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                         5 cod_modulo,
                         substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                         substr(f.seg_nombre, 1, 15) seg_nombre,
                         substr(f.pri_apellido, 1, 20) pri_apellido,
                         substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                           pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido),
                                1, 20) seg_apellido,
                         decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                         (c_fec_actual - s.dia_atraso) fec_operacion,
                         3 tip_operacion,
                         0 nro_cuota,
                         NULL can_cuotas,
                         decode(nvl(w.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                         0 mto_cuota,
                         NULL fec_final,
                         ' ' tip_actualizacion,
                         'M' periodicidad,
                         NULL pri_cuo_atrasada,
                         1 can_cuo_atrasada,
                         NULL pri_fec_ven_atrasada,
                         NULL fec_ult_pago,
                         s.sal_total sal_mora,
                         51 cod_modalidad,
                         w.cod_moneda,
                         'INC-1.4' observacion,
                         s.dia_atraso dias_atraso,
                         s.nro_cuenta nro_cta_nueva,
                         15 cod_ori_modulo,
                         151 cod_ori_modalidad,
                         NULL cod_sec_credito
           FROM ov_cta_vencidas  s,
                ge_cta_clientes  t,
                ge_clientes      l,
                ba_personas      p,
                ba_per_fisicas   f,
                ba_per_juridicas j,
                ge_cuentas       w,
                ge_est_cuentas   e
          WHERE s.nro_cta_origen = w.nro_cuenta
            AND s.nro_cta_origen = t.nro_cuenta
            AND s.cod_modulo = 15
            AND s.cod_modalidad = 151
            AND t.relacion IN ('P')
            AND s.estado <> 'C'
            AND fug_es_empleado(l.cod_persona) = 'N'
               --*****************************************************************
               /** No debe enviar los que ya fueron enviados en TA_CTA_TARJETAS. **/
            AND NOT EXISTS
          (SELECT 1
                   FROM co_inf_cob_diarios f
                  WHERE f.nro_cuenta = s.nro_cta_origen
                    AND f.cod_modulo = 5
                    AND f.fec_envio < c_fec_actual)
            AND t.cod_persona = l.cod_persona
            AND l.cod_persona = p.cod_persona
            AND l.cod_persona = f.cod_persona(+)
            AND l.cod_persona = j.cod_persona(+)
            AND t.nro_cuenta = w.nro_cuenta
            AND s.cod_modulo = e.cod_modulo
            AND s.cod_modalidad = e.cod_modalidad
            AND nvl(t.relacion, 'x') = 'P'
               /** Para parametro de mto_mora. **/
            AND nvl(s.sal_total, 0) > nvl(v_sal_min_tar_cob_informconf, 0)
            AND nvl(s.sal_total, 0) <= v_sal_max_tar_cobranzas
            AND ((s.dia_atraso >= nvl(v_dia_atr_ini_tar_informconf, 0) AND l.cli_especial = 'N') OR
                (s.dia_atraso >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND l.cli_especial = 'S'))
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
            AND e.activo = 'S'
               /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
               Debe ser nulo o Pertenecer a cualquier Banca. **/
            AND l.cod_usu_oficial IN
                (SELECT cod_usuario
                   FROM ba_usuarios
                  WHERE oficial = 'S'
                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                        cod_banca IS NULL))
            AND NOT EXISTS (SELECT 1
                   FROM co_inf_cob_personas z
                  WHERE z.cod_persona = l.cod_persona
                    AND z.nro_cuenta = s.nro_cta_origen --s.nro_cuenta
                    AND z.nro_cuota = 0
                    AND z.observacion = 'INC-1.4')
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS
          (SELECT 1
                   FROM ge_tra_prohibidas z
                  WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND z.cod_modulo = w.cod_modulo
                    AND z.cod_modalidad = w.cod_modalidad
                    AND z.nro_cuenta = s.nro_cta_origen) --s.nro_cuenta )
               /** Para que excluya los que no se envian a informconf. **/
            AND p.cod_persona NOT IN (SELECT cod_persona
                                        FROM ba_per_dat_adicionales
                                       WHERE parametro LIKE 'ENV_INFORMCONF'
                                         AND val_parametro = 'N')
               /** No incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = l.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** No incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
         /** Agregado para CC_CTA_CORRIENTES que no pasaron a vencidas e ingresaron en el rango. **/
         UNION ALL
         SELECT DISTINCT p.cod_persona,
                         x.nro_cuenta,
                         substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                         w.cod_modulo,
                         substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                         substr(f.seg_nombre, 1, 15) seg_nombre,
                         substr(f.pri_apellido, 1, 20) pri_apellido,
                         substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                           pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido),
                                1, 20) seg_apellido,
                         decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                         (c_fec_actual - r.can_dias) fec_operacion,
                         4 tip_operacion,
                         0 nro_cuota,
                         NULL can_cuotas,
                         decode(nvl(w.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                         0 mto_cuota,
                         NULL fec_final,
                         ' ' tip_actualizacion,
                         'M' periodicidad,
                         NULL pri_cuo_atrasada,
                         1 can_cuo_atrasada,
                         NULL pri_fec_ven_atrasada,
                         NULL fec_ult_pago,
                         r.mto_mora sal_mora,
                         w.cod_modalidad,
                         w.cod_moneda,
                         'INC-1.6' observacion,
                         r.can_dias dias_atraso,
                         NULL nro_cta_nueva,
                         4 cod_ori_modulo,
                         41 cod_ori_modalidad,
                         NULL cod_sec_credito
           FROM cc_cta_corrientes x,
                ge_cta_clientes   t,
                ge_clientes       l,
                ba_personas       p,
                ba_per_fisicas    f,
                ba_per_juridicas  j,
                ge_cuentas        w,
                ge_est_cuentas    e,
                cc_sobregiros_res r
          WHERE x.nro_cuenta = t.nro_cuenta
            AND t.cod_persona = l.cod_persona
            AND l.cod_persona = p.cod_persona
            AND l.cod_persona = f.cod_persona(+)
            AND l.cod_persona = j.cod_persona(+)
            AND t.nro_cuenta = w.nro_cuenta
            AND w.cod_modulo = e.cod_modulo
            AND w.cod_modalidad = e.cod_modalidad
            AND x.nro_cuenta = r.nro_cuenta(+)
            AND nvl(t.relacion, 'x') = 'P'
            AND fug_es_empleado(l.cod_persona) = 'N'
            AND ((r.can_dias >= nvl(v_dia_atr_ini_tar_informconf, 0) AND l.cli_especial = 'N') OR
                (r.can_dias >= nvl(v_dia_atr_ini_sob_informconf, 0) AND l.cli_especial = 'S'))
            AND x.estado = 'N'
            AND nvl(r.mto_mora, 0) > v_sal_min_sob_cobranzas
            AND nvl(r.mto_mora, 0) <= v_sal_max_sob_cobranzas
            AND nvl(r.can_dias, 0) >= v_dia_atr_ini_pre_informconf
            AND NOT EXISTS
          (SELECT j.nro_cta_origen
                   FROM ov_cta_vencidas j
                  WHERE j.nro_cta_origen = x.nro_cuenta
                    AND j.cod_modalidad = 152)
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
            AND e.activo = 'S'
               /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
               Debe ser nulo o Pertenecer a cualquier Banca. **/
            AND l.cod_usu_oficial IN
                (SELECT cod_usuario
                   FROM ba_usuarios
                  WHERE oficial = 'S'
                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                        cod_banca IS NULL))
            AND NOT EXISTS (SELECT 1
                   FROM co_inf_cob_personas s
                  WHERE s.cod_persona = l.cod_persona
                    AND s.nro_cuenta = x.nro_cuenta
                    AND s.nro_cuota = 0)
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS
          (SELECT 1
                   FROM ge_tra_prohibidas z
                  WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND z.cod_modulo = w.cod_modulo
                    AND z.cod_modalidad = w.cod_modalidad
                    AND z.nro_cuenta = x.nro_cuenta)
               /** Para que excluya los que no se envian a informconf. **/
            AND p.cod_persona NOT IN (SELECT cod_persona
                                        FROM ba_per_dat_adicionales
                                       WHERE parametro LIKE 'ENV_INFORMCONF'
                                         AND val_parametro = 'N')
               /** No incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = l.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** No incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
         --**************************************************************
          ORDER BY 5, -- Primer Nombre/Razón Social
                   6, -- Segundo Nombre
                   7, -- Primer Apellido
                   8, -- segundo Apellido
                   2, -- Número de Cuenta
                   12; -- Número de Cuota

      CURSOR modificaciones IS
      /** Esta primera parte recupera las nuevas cuotas que entran en mora de cuentas que no sufrieron pagos y ya estaban incluidas. **/
         SELECT DISTINCT p.cod_persona,
                         c.nro_cuenta,
                         substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                         c.cod_modulo,
                         substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                         substr(f.seg_nombre, 1, 15) seg_nombre,
                         substr(f.pri_apellido, 1, 20) pri_apellido,
                         substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                           pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido),
                                1, 20) seg_apellido,
                         decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                         c.fec_inicio fec_operacion,
                         1 tip_operacion,
                         (SELECT MIN(pr.nro_cuota)
                            FROM pr_cuotas pr
                           WHERE pr.nro_cuenta = u.nro_cuenta
                             AND nvl(pr.nro_cuota, 0) > 0
                             AND nvl(pr.estado, 'x') <> 'N'
                             AND pr.fec_vencimiento <= c_fec_actual) nro_cuota,
                         c.can_cuotas,
                         decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                         (nvl(u.mto_capital, 0) + nvl(u.mto_interes, 0)) mto_cuota,
                         to_date(NULL, 'DD/MM/YYYY') fec_final,
                         'D' tip_actualizacion,
                         'M' periodicidad,
                         z.pri_cuo_atr pri_cuo_atrasada,
                         z.can_cuo_atr can_cuo_atrasada,
                         z.pri_fec_ven_atr pri_fec_ven_atrasada,
                         b.fec_ult_pago,
                         z.sal_cuo_mora sal_mora,
                         c.cod_modalidad,
                         c.cod_moneda,
                         NULL nro_tarjeta,
                         'MOD-1.1' observacion,
                         w.dia_atraso dias_atraso,
                         NULL nro_cta_nueva,
                         NULL cod_ori_modulo,
                         NULL cod_ori_modalidad,
                         c.cod_sec_credito
           FROM pr_cta_prestamos c,
                ge_cta_clientes t,
                ge_clientes l,
                ba_personas p,
                ba_per_fisicas f,
                ba_per_juridicas j,
                pr_cuotas u,
                ge_est_cuentas e,
                ge_par_dinamicos o,
                ge_cuentas w,
                (SELECT x.nro_cuenta nro_cta, MAX(x.fecha) fec_ult_pago
                   FROM co_inf_cob_personas q, pr_cobros x
                  WHERE x.fecha >= v_fec_ult_env
                    AND nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                        nvl(x.mto_int_documentado, 0) > 0
                    AND EXISTS
                  (SELECT 1 FROM co_inf_cob_personas q WHERE q.nro_cuenta = x.nro_cuenta)
                  GROUP BY x.nro_cuenta) b,
                (SELECT x.nro_cuenta nro_cta,
                        MIN(x.nro_cuota) pri_cuo_atr,
                        COUNT(*) can_cuo_atr,
                        MIN(x.fec_vencimiento) pri_fec_ven_atr,
                        SUM(nvl(x.sal_capital, 0) + nvl(x.sal_interes, 0) +
                            nvl(x.sal_int_documentado, 0)) sal_cuo_mora
                   FROM pr_cuotas x
                  WHERE x.nro_cuota <> 0
                    AND x.estado <> 'N'
                    AND x.fec_vencimiento <= c_fec_actual
                    AND EXISTS
                  (SELECT 1 FROM co_inf_cob_personas q WHERE q.nro_cuenta = x.nro_cuenta)
                  GROUP BY x.nro_cuenta) z
          WHERE c.nro_cuenta = t.nro_cuenta
            AND l.cod_persona = t.cod_persona
            AND t.nro_cuenta = w.nro_cuenta
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
            AND nvl(t.relacion, 'x') = 'P'
            AND ((nvl(c.dia_atraso, 0) >= nvl(v_dia_atr_ini_pre_informconf, 0) AND
                l.cli_especial = 'N') OR
                (nvl(c.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                l.cli_especial = 'S'))
            AND l.cod_persona = p.cod_persona
            AND l.cod_persona = f.cod_persona(+)
            AND l.cod_persona = j.cod_persona(+)
            AND c.nro_cuenta = u.nro_cuenta
            AND nvl(u.nro_cuota, 0) > 0
            AND nvl(u.estado, 'x') <> 'N'
            AND u.fec_vencimiento <= c_fec_actual
            AND c.nro_cuenta = b.nro_cta(+)
            AND c.nro_cuenta = z.nro_cta
            AND nvl(z.sal_cuo_mora, 0) > v_sal_min_pre_cobranzas
            AND nvl(z.sal_cuo_mora, 0) <= v_sal_max_pre_cobranzas
            AND c.cod_modulo = e.cod_modulo
            AND c.cod_modalidad = e.cod_modalidad
            AND c.estado = e.estado
            AND e.activo = 'S'
            AND c.estado <> 'I'
               /** Por módulo y modalidad solo los que el par. dinámico= 'S'. **/
            AND o.parametro = 'MOD_COBRANZAS'
            AND nvl(o.val_parametro, 'N') = 'S'
            AND o.cod_modulo = c.cod_modulo
            AND o.cod_modalidad = c.cod_modalidad
               /** Para bancas(Join ge_clientes, ba_usuarios para cod_banca). **/
            AND l.cod_usu_oficial IN
                (SELECT cod_usuario
                   FROM ba_usuarios
                  WHERE oficial = 'S'
                       /** Debe ser nulo o Pertenecer a cualquier Banca, si se desea enviar mas
                       bancas en un futuro se debe de incluir en el par_dinamico(TIP_BAN_INFORMCONF) ej.(1,2,3,...etc.) para el IN. **/
                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                        cod_banca IS NULL))
               --*******************************************************
               /** Si existe en informado quiere decir que se envió ya a informconf. **/
            AND EXISTS (SELECT 1 --- Que exista informado
                   FROM co_inf_cob_personas x
                  WHERE x.cod_persona = l.cod_persona
                    AND x.nro_cuenta = c.nro_cuenta)
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS (SELECT 1
                   FROM ge_tra_prohibidas z
                  WHERE z.cod_transaccion IN (nvl(v_cod_tra_prohibida, '0')) -- No enviar a Cobranzas
                    AND z.cod_modulo = c.cod_modulo
                    AND z.cod_modalidad = c.cod_modalidad
                    AND z.nro_cuenta = c.nro_cuenta)
               /** o no es 5-CASH COLLATERAL. **/
            AND NOT EXISTS (SELECT 1
                   FROM pr_cta_garantias x
                  WHERE x.nro_cuenta = c.nro_cuenta
                    AND x.cod_garantia = 5)
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = l.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
            AND NOT EXISTS
          (SELECT 1 /** Que esta cuota no se haya informado aún. **/
                   FROM co_inf_cob_personas x
                  WHERE x.cod_persona = l.cod_persona
                    AND x.nro_cuenta = c.nro_cuenta
                    AND x.nro_cuota = (SELECT MIN(pr.nro_cuota)
                                         FROM pr_cuotas pr
                                        WHERE pr.nro_cuenta = u.nro_cuenta
                                          AND nvl(pr.nro_cuota, 0) > 0
                                          AND nvl(pr.estado, 'x') <> 'N'
                                          AND pr.fec_vencimiento <= c_fec_actual))
            AND EXISTS (SELECT MAX(x.fec_ult_pago), MAX(q.fecha)
                   FROM co_inf_cob_personas x, pr_cobros q
                  WHERE x.cod_persona = l.cod_persona
                    AND x.nro_cuenta = c.nro_cuenta
                    AND x.nro_cuenta = q.nro_cuenta
                    AND x.nro_cuota = q.nro_cuota
                    AND nvl(q.mto_capital, 0) + nvl(q.mto_interes, 0) +
                        nvl(q.mto_int_documentado, 0) > 0
                  HAVING(MAX(x.fec_ult_pago) IS NULL
                            OR MAX(x.fec_ult_pago) = MAX(q.fecha)))
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
         UNION ALL
         SELECT p.cod_persona,
                c.nro_cuenta,
                substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                c.cod_modulo,
                substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                substr(f.seg_nombre, 1, 15) seg_nombre,
                substr(f.pri_apellido, 1, 20) pri_apellido,
                substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                  pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido), 1, 20) seg_apellido,
                decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                       substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                c.fec_apertura fec_operacion,
                3 tip_operacion,
                0 nro_cuota,
                NULL can_cuotas,
                decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1, nvl(c.mto_mora, 0),
                       /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                       nvl(c.mto_mora, 0),
                       /** Si el pago mínimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                       nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)) mto_cuota,
                to_date(NULL, 'DD/MM/YYYY') fec_final,
                'D' tip_actualizacion,
                'M' periodicidad,
                NULL pri_cuo_atrasada,
                1 can_cuo_atrasada,
                (c_fec_actual - nvl(c.dia_mora, 0)) pri_fec_ven_atrasada,
                MAX(b.fec_proceso) fec_ult_pago,
                decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1, nvl(c.mto_mora, 0),
                       /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                       nvl(c.mto_mora, 0),
                       /** Si el pago mínimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                       nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)) sal_mora,
                c.cod_modalidad,
                c.cod_moneda,
                NULL nro_tarjeta,
                'MOD-1.2' observacion,
                w.dia_atraso dias_atraso,
                NULL nro_cta_nueva,
                NULL cod_ori_modulo,
                NULL cod_ori_modalidad,
                NULL cod_sec_credito
           FROM ta_cta_tarjetas  c,
                ge_cta_clientes  t,
                ge_clientes      l,
                ba_personas      p,
                ba_per_fisicas   f,
                ba_per_juridicas j,
                ta_cobros        b,
                ge_est_cuentas   e,
                ge_par_dinamicos o,
                ge_cuentas       w
          WHERE c.nro_cuenta = t.nro_cuenta
            AND l.cod_persona = t.cod_persona
            AND nvl(t.relacion, 'x') = 'P'
            AND ((nvl(c.dia_mora, 0) >= nvl(v_dia_atr_ini_tar_informconf, 0) AND
                l.cli_especial = 'N') OR
                (nvl(c.dia_mora, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                l.cli_especial = 'S'))
            AND nvl(c.mto_mora, 0) > v_sal_min_tar_cob_informconf
            AND nvl(c.mto_mora, 0) <= v_sal_max_tar_cobranzas
            AND l.cod_persona = p.cod_persona
            AND l.cod_persona = f.cod_persona(+)
            AND l.cod_persona = j.cod_persona(+)
            AND c.nro_cuenta = b.nro_cuenta(+)
            AND nvl(b.fec_proceso(+), c_fec_actual) >= v_fec_ult_env
            AND nvl(b.fec_proceso(+), c_fec_actual) <
                decode(b.fec_proceso(+), NULL, c_fec_actual + 1, c_fec_actual)
            AND c.cod_modulo = e.cod_modulo
            AND c.cod_modalidad = e.cod_modalidad
            AND c.estado = e.estado
            AND t.nro_cuenta = w.nro_cuenta
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
            AND e.activo = 'S'
            AND c.estado <> 'I'
            --AND nvl(c.en_juicio, 'N') = 'N' V.O. 17-10-13
               /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
               Debe ser nulo o Pertenecer a cualquier Banca, si se desea enviar mas
               bancas en un futuro se debe de incluir en el par_dinamico(TIP_BAN_INFORMCONF) ej.(1,2,3,...etc.) para el IN. **/
            AND l.cod_usu_oficial IN
                (SELECT cod_usuario
                   FROM ba_usuarios
                  WHERE oficial = 'S'
                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                        cod_banca IS NULL))
               /** Por módulo y modalidad solo los que el par. dinámico = 'S'. **/
            AND o.parametro = 'MOD_COBRANZAS'
            AND nvl(o.val_parametro, 'N') = 'S'
            AND o.cod_modulo = c.cod_modulo
            AND o.cod_modalidad = c.cod_modalidad
               --***********************************************************
            AND (EXISTS (SELECT 1
                           FROM co_inf_cob_personas x
                          WHERE x.cod_persona = l.cod_persona
                            AND x.nro_cuenta = c.nro_cuenta
                            AND x.nro_cuota = 0
                            AND nvl(x.mto_deuda, 0) <>
                                decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1,
                                       nvl(c.mto_mora, 0),
                                       /** Si el monto en mora es mayor, entonces se informa este. **/
                                       0, nvl(c.mto_mora, 0),
                                       /** Si el pago mínimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                                       nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0))) /** aqui está Modificando el monto informado de las tarjetas (nuevo extracto en mora). **/
                )
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS (SELECT 1
                   FROM ge_tra_prohibidas z
                  WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND z.cod_modulo = c.cod_modulo
                    AND z.cod_modalidad = c.cod_modalidad
                    AND z.nro_cuenta = c.nro_cuenta)
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = l.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
          GROUP BY p.cod_persona,
                   c.nro_cuenta,
                   substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15),
                   c.cod_modulo,
                   substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65),
                   substr(f.seg_nombre, 1, 15),
                   substr(f.pri_apellido, 1, 20),
                   substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                     pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido), 1,
                          20),
                   decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                          substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)),
                   c.fec_apertura,
                   3,
                   0,
                   NULL,
                   decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D'),
                   nvl(c.mto_pag_minimo, 0),
                   to_date(NULL, 'DD/MM/YYYY'),
                   ' ',
                   'M',
                   NULL,
                   NULL,
                   (c_fec_actual - nvl(c.dia_mora, 0)),
                   decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1, nvl(c.mto_mora, 0),
                          /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                          nvl(c.mto_mora, 0),
                          /** Si el pago mínimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                          nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)),
                   c.cod_modalidad,
                   c.cod_moneda,
                   w.dia_atraso
         UNION ALL
         /** ENVIO DE PAGOS. **/
         SELECT o.cod_persona,
                o.nro_cuenta,
                o.nro_documento,
                o.cod_modulo,
                o.pri_nombre,
                o.seg_nombre,
                o.pri_apellido,
                o.seg_apellido,
                o.ape_casada,
                o.fec_operacion,
                to_number(o.tip_inf_operacion),
                o.nro_cuota,
                o.can_cuotas,
                o.tip_inf_moneda,
                o.mto_cuota,
                o.fec_final,
                'P' tip_inf_actualizacion,
                o.inf_periodicidad,
                o.pri_cuo_atrasada,
                o.can_cuo_atrasada,
                o.fec_vencimiento pri_fec_ven_atrasada,
                b.fec_ult_pago,
                o.mto_deuda sal_mora,
                o.cod_modalidad,
                o.cod_moneda,
                o.nro_tarjeta,
                'MOD-1.3' observacion,
                decode(nvl(g.dia_atraso, 0), 0, 1, g.dia_atraso) dias_atraso,
                NULL nro_cta_nueva,
                NULL cod_ori_modulo,
                NULL cod_ori_modalidad,
                o.cod_sec_credito
           FROM co_inf_cob_personas o,
                ge_cuentas g,
                (SELECT x.nro_cuenta nro_cta, x.nro_cuota nro_cuo, MAX(x.fecha) fec_ult_pago
                   FROM co_inf_cob_personas q, pr_cobros x
                  WHERE q.nro_cuenta = x.nro_cuenta
                    AND q.nro_cuota = x.nro_cuota
                    AND nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                        nvl(x.mto_int_documentado, 0) > 0
                    AND x.fecha >= v_fec_ult_env
                  GROUP BY x.nro_cuenta, x.nro_cuota) b
          WHERE o.nro_cuenta = g.nro_cuenta
            AND g.estado <> 'I'
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(o.cod_persona) = 'N'
            AND o.nro_cuenta = b.nro_cta
            AND o.nro_cuota = b.nro_cuo
            AND (nvl(o.fec_ult_pago, trunc(SYSDATE) - 360) < b.fec_ult_pago OR NOT EXISTS
                 (SELECT 1
                    FROM ge_cuentas x, ge_cta_clientes y, ge_clientes z
                   WHERE x.nro_cuenta = o.nro_cuenta
                     AND x.cod_modulo = o.cod_modulo
                     AND x.nro_cuenta = y.nro_cuenta
                     AND z.cod_persona = y.cod_persona
                     AND y.relacion IN ('P')
                     AND ((nvl(x.dia_atraso, 0) >= nvl(v_dia_atr_ini_pre_informconf, 0) AND
                         z.cli_especial = 'N') OR
                         (nvl(x.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                         z.cli_especial = 'S'))))
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS (SELECT 1
                   FROM ge_tra_prohibidas h
                  WHERE h.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND h.cod_modulo = o.cod_modulo
                    AND h.cod_modalidad = o.cod_modalidad
                    AND h.nro_cuenta = o.nro_cuenta)
               /** NO enviar como cobradas operaciones RRR. **/
            AND NOT EXISTS (SELECT 1
                   FROM pr_cta_prestamos p
                  WHERE p.nro_cuenta = o.nro_cuenta
                    AND p.estado = 'N'
                    AND p.nro_cta_renovada IS NOT NULL)
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         UNION ALL
         SELECT o.cod_persona,
                o.nro_cuenta,
                o.nro_documento,
                o.cod_modulo,
                o.pri_nombre,
                o.seg_nombre,
                o.pri_apellido,
                o.seg_apellido,
                o.ape_casada,
                o.fec_operacion,
                to_number(o.tip_inf_operacion),
                o.nro_cuota,
                o.can_cuotas,
                o.tip_inf_moneda,
                o.mto_cuota,
                o.fec_final,
                'P' tip_inf_actualizacion,
                o.inf_periodicidad,
                o.pri_cuo_atrasada,
                o.can_cuo_atrasada,
                o.fec_vencimiento pri_fec_ven_atrasada,
                b.fec_ult_pago,
                o.mto_deuda sal_mora,
                o.cod_modalidad,
                o.cod_moneda,
                o.nro_tarjeta,
                'MOD-1.4' observacion,
                nvl(g.dia_atraso, 0) dias_atraso,
                NULL nro_cta_nueva,
                NULL cod_ori_modulo,
                NULL cod_ori_modalidad,
                o.cod_sec_credito
           FROM co_inf_cob_personas o,
                ge_cuentas g,
                (SELECT x.nro_cuenta nro_cta, MAX(x.fec_proceso) fec_ult_pago
                   FROM co_inf_cob_personas q, ta_cobros x
                  WHERE q.nro_cuenta = x.nro_cuenta
                    AND x.fec_proceso >= v_fec_ult_env
                    AND x.fec_proceso < c_fec_actual
                       /** Para que no se remita como cobradas las tarjetas con saldo insuficiente. **/
                    AND x.estado = 'P'
                  GROUP BY x.nro_cuenta) b
          WHERE o.nro_cuenta = g.nro_cuenta
            AND g.estado <> 'I'
            --AND nvl(g.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(o.cod_persona) = 'N'
            AND o.nro_cuenta = b.nro_cta
            AND (nvl(o.fec_ult_pago, trunc(SYSDATE) - 360) < b.fec_ult_pago OR NOT EXISTS
                 (SELECT 1
                    FROM ge_cuentas x, ge_cta_clientes y, ge_clientes z
                   WHERE x.nro_cuenta = o.nro_cuenta
                     AND x.cod_modulo = o.cod_modulo
                     AND x.nro_cuenta = y.nro_cuenta
                     AND z.cod_persona = y.cod_persona
                     AND y.relacion = 'P'
                     AND ((nvl(x.dia_atraso, 0) >=
                         decode(x.cod_modulo, 5, nvl(v_dia_atr_ini_tar_informconf, 0), 6,
                                  nvl(v_dia_atr_ini_pre_informconf, 0)) AND z.cli_especial = 'N') OR
                         (nvl(x.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                         z.cli_especial = 'S'))
                     AND nvl(x.mto_mora, 0) > v_sal_min_tar_cob_informconf))
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS (SELECT 1
                   FROM ge_tra_prohibidas h
                  WHERE h.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND h.cod_modulo = o.cod_modulo
                    AND h.cod_modalidad = o.cod_modalidad
                    AND h.nro_cuenta = o.nro_cuenta)
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)

         /** ENVIO DE PAGO DE SOBREGIRO.**/
         UNION ALL
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'P' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.4' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         o.nro_cta_nueva,
                         o.cod_ori_modulo,
                         o.cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o
          WHERE o.tip_inf_operacion = 4
            AND EXISTS (SELECT 1
                   FROM ov_cobros w
                  WHERE w.nro_cuenta = o.nro_cta_nueva --o.nro_cuenta
                    AND trunc(w.fecha) = trunc(c_fec_actual))
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         /** Envio de Pagos de Tarjetas Vencidas. **/
         UNION ALL
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'P' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.5' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         o.nro_cta_nueva,
                         o.cod_ori_modulo,
                         o.cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o
          WHERE o.tip_inf_operacion = 3
            AND o.cod_modulo = 5
            AND EXISTS (SELECT 1
                   FROM ov_cobros w
                  WHERE w.nro_cuenta = o.nro_cta_nueva --o.nro_cuenta
                    AND trunc(w.fecha) = trunc(c_fec_actual))
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         /** Envio de Pagos de CC_CTA_VENCIDAS. **/
         UNION ALL
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'P' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.6' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         NULL nro_cta_nueva,
                         4 cod_ori_modulo,
                         41 cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o, cc_cta_corrientes w, cc_sobregiros_res r
          WHERE o.tip_inf_operacion = 4
            AND o.nro_cuenta = w.nro_cuenta
            AND w.nro_cuenta = r.nro_cuenta(+)
            AND w.estado <> 'C'
            AND o.mto_cuota > r.mto_mora
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         UNION ALL
         /** Envio los que el proceso de Cierre de Mes hizo que aumentaran su deuda (Mto_Mora), se informa como incremento. **/
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'D' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.7' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         NULL nro_cta_nueva,
                         4 cod_ori_modulo,
                         41 cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o, cc_cta_corrientes w, cc_sobregiros_res r
          WHERE o.tip_inf_operacion = 4
            AND o.nro_cuenta = w.nro_cuenta
            AND w.nro_cuenta = r.nro_cuenta(+)
            AND w.estado <> 'C'
            AND o.mto_cuota < r.mto_mora
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera.**/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         UNION ALL
         /** Envio los que ya fueron enviadas como tarjetas o cc_cta_corrientes
         y aumentaron su deuda al pasar a vencidas. **/
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'D' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.9' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         w.nro_cuenta nro_cta_nueva,
                         o.cod_ori_modulo,
                         o.cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o, ov_cta_vencidas w
          WHERE o.tip_inf_operacion IN (3, 4)
            AND o.nro_cuenta = w.nro_cta_origen
            AND nvl(o.mto_cuota, 0) < nvl(w.sal_total, 0)
            AND w.estado <> 'C'
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
          ORDER BY 5, -- Primer Nombre/Razón Social
                   6, -- Segundo Nombre
                   7, -- Primer Apellido
                   8, -- segundo Apellido
                   2, -- Número de Cuenta
                   12; -- Número de Cuota
      CURSOR exclusiones IS
         SELECT o.cod_persona,
                o.nro_cuenta,
                o.nro_cuota,
                o.nro_documento,
                o.pri_nombre,
                o.seg_nombre,
                o.pri_apellido,
                o.seg_apellido,
                o.ape_casada,
                o.dir_particular,
                o.dir_laboral,
                o.dir_lab_alternativo,
                o.tel_particular,
                o.tel_laboral,
                o.tel_lab_alternativo,
                o.fec_operacion,
                o.can_cuotas,
                o.tip_inf_operacion,
                o.pri_cuo_atrasada,
                o.can_cuo_atrasada,
                o.mto_cuota,
                o.fec_vencimiento,
                o.fec_ult_pago,
                o.nro_tarjeta,
                o.tip_inf_garantia,
                o.tip_inf_moneda,
                o.mto_deuda,
                o.fec_final,
                o.tip_inf_cobro,
                o.mto_cobrado,
                o.fec_cobro,
                o.tip_inf_actualizacion,
                o.inf_periodicidad,
                o.cod_modulo,
                o.cod_modalidad,
                o.cod_moneda,
                'Exc-1' observacion
           FROM co_inf_cob_personas o,
                ba_per_fisicas      f,
                ba_per_juridicas    j,
                ge_cuentas          g,
                ge_par_dinamicos    d,
                ge_est_cuentas      e
          WHERE (NOT EXISTS (SELECT 1 FROM ge_cuentas c WHERE c.nro_cuenta = o.nro_cuenta) OR
                /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
                 EXISTS (SELECT 1
                           FROM ge_tra_prohibidas h
                          WHERE h.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                            AND h.cod_modulo = o.cod_modulo
                            AND h.cod_modalidad = o.cod_modalidad
                            AND h.nro_cuenta = o.nro_cuenta) OR NOT EXISTS
                 (SELECT 1 /**Se agregó para que elimine las cuentas que no tengan dias de mora ni monto en mora. **/
                    FROM ge_cuentas x, ge_cta_clientes y, ge_clientes z
                   WHERE x.nro_cuenta = o.nro_cuenta
                     AND x.cod_modulo = o.cod_modulo
                     AND x.nro_cuenta = y.nro_cuenta
                     AND z.cod_persona = y.cod_persona
                     AND y.relacion IN ('P')
                     AND ((nvl(x.dia_atraso, 0) >=
                         decode(x.cod_modulo, 5, nvl(v_dia_atr_ini_tar_informconf, 0), 6,
                                  nvl(v_dia_atr_ini_pre_informconf, 0)) AND z.cli_especial = 'N') OR
                         (nvl(x.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                         z.cli_especial = 'S'))

                        /** Excluye las TARJETAS con montos inferiores al parametro. **/
                     AND (x.cod_modulo <> 5 OR
                         nvl(x.mto_mora, 0) > nvl(v_sal_min_tar_cob_informconf, 0))) OR
                --o es 5-CASH COLLATERAL
                 EXISTS (SELECT 1
                           FROM pr_cta_garantias x
                          WHERE x.nro_cuenta = o.nro_cuenta
                            AND x.cod_garantia = 5) OR EXISTS
                 (SELECT 1
                    FROM ba_usuarios u
                   WHERE u.cod_persona = o.cod_persona
                     AND nvl(u.estado, 'A') <> 'I') OR e.activo <> 'S' OR g.estado = 'I' OR
                 /*nvl(g.en_juicio, 'N') = 'S'*/
                 fu_ver_cli_judicial(o.cod_persona) = 'N' OR nvl(d.val_parametro, 'N') = 'N')
            AND o.cod_persona = f.cod_persona(+)
            AND o.cod_persona = j.cod_persona(+)
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(g.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(o.cod_persona) = 'N'
               /** Por módulo y modalidad solo los que el par.dinámico='S'. **/
            AND d.parametro = 'MOD_COBRANZAS'
            AND d.cod_modulo = o.cod_modulo
            AND d.cod_modalidad = o.cod_modalidad
               --**************************************
            AND o.nro_cuenta = g.nro_cuenta
            AND e.cod_modulo = g.cod_modulo
            AND e.cod_modalidad = g.cod_modalidad
            AND e.estado = g.estado
               /** Que no incluya las tarjetas vencidas. **/
            AND (((o.cod_modulo = 5 AND o.observacion <> 'INC-1.4') AND NOT EXISTS
                 (SELECT 1
                     FROM ta_cobros j
                    WHERE j.nro_cuenta = o.nro_cuenta
                      AND j.fec_proceso >= v_fec_ult_env
                      AND j.fec_proceso < c_fec_actual)) OR
                (o.cod_modulo = 6 AND NOT EXISTS
                 (SELECT 1
                     FROM pr_cobros k
                    WHERE k.nro_cuenta = o.nro_cuenta
                      AND k.fecha >= v_fec_ult_env
                      AND nvl(k.mto_capital, 0) + nvl(k.mto_interes, 0) +
                          nvl(k.mto_int_documentado, 0) > 0)))
          ORDER BY decode(f.pri_apellido, NULL, j.raz_social, f.pri_nombre),
                   f.seg_apellido,
                   f.pri_nombre,
                   f.seg_nombre;

      FUNCTION lf_obt_garantia
      (
         p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
         p_cod_modulo  ge_cuentas.cod_modulo%TYPE,
         p_observacion VARCHAR2
      ) RETURN NUMBER IS
         v_cod NUMBER(3);
      BEGIN
         IF p_cod_modulo = 5 AND p_observacion IN ('INC-1.2', 'MOD-1.2') THEN
            /** Si es tarjeta Normal. **/
            BEGIN
               SELECT cod_garantia
                 INTO v_cod
                 FROM ta_cta_garantias
                WHERE nro_cuenta = p_nro_cuenta
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cod := NULL;
            END;
         ELSIF p_cod_modulo = 5 AND p_observacion NOT IN ('INC-1.2', 'MOD-1.2') THEN
            /** Si es tarjeta Vencida. **/
            BEGIN
               SELECT c.cod_garantia
                 INTO v_cod
                 FROM ov_cta_vencidas a, ta_cta_tarjetas b, ta_cta_garantias c
                WHERE a.nro_cta_origen = b.nro_cuenta
                  AND b.nro_cuenta = c.nro_cuenta
                  AND a.nro_cuenta = p_nro_cuenta
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cod := NULL;
            END;
         ELSIF p_cod_modulo = 6 THEN
            /** Si es préstamo. **/
            BEGIN
               SELECT cod_garantia
                 INTO v_cod
                 FROM pr_cta_garantias
                WHERE nro_cuenta = p_nro_cuenta
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cod := NULL;
            END;
            /** Se busca la garantia en sobregiros o cta_cte. **/
         ELSIF p_cod_modulo = 4 THEN
            /** Si es sobregiro o cta_cte se asume a sola firma. **/
            v_cod := 1;

         END IF;
         RETURN v_cod;
      END lf_obt_garantia;

      /** Procedimiento donde se obtiene el Pago Realizado. **/
      PROCEDURE lp_obt_pago
      (
         p_nro_cuenta   IN ge_cuentas.nro_cuenta%TYPE,
         p_nro_cuota    IN pr_cuotas.nro_cuota%TYPE,
         p_cod_modulo   IN ge_cuentas.cod_modulo%TYPE,
         p_tip_cobro    OUT VARCHAR2,
         p_fec_ult_pago OUT DATE,
         p_mto_ult_pago OUT NUMBER,
         p_tip_informe  IN VARCHAR2,
         p_can_cuotas   pr_cuotas.nro_cuota%TYPE
      ) IS
         v_old_fec_cobro DATE;
         v_new_fec_cobro DATE;
         v_new_mto_cobro NUMBER(18, 2);
         v_new_mto_cuota NUMBER(18, 2);
      BEGIN
         BEGIN
            SELECT nvl(fec_cobro, fec_ini_envio
                       /*decode(fec_ini_envio, to_date('01/01/2010', 'DD/MM/YYYY'), trunc(SYSDATE) - 3,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               fec_ini_envio)*/)
              INTO v_old_fec_cobro
              FROM co_inf_cob_personas
             WHERE nro_cuenta = p_nro_cuenta
               AND nro_cuota = p_nro_cuota;
         EXCEPTION
            WHEN OTHERS THEN
               v_old_fec_cobro := to_date('01/01/1900', 'DD/MM/YYYY');
         END;
         /** Si es tarjeta. **/
         IF p_cod_modulo = 5 THEN
            BEGIN
               SELECT MAX(c.fec_proceso), SUM(c.monto)
                 INTO v_new_fec_cobro, v_new_mto_cobro
                 FROM ta_cobros c
                WHERE c.nro_cuenta = p_nro_cuenta
                  AND c.fec_proceso >= v_old_fec_cobro
                  AND c.fec_proceso < c_fec_actual;
            EXCEPTION
               WHEN OTHERS THEN
                  v_new_fec_cobro := NULL;
                  v_new_mto_cobro := NULL;
            END;
            IF v_old_fec_cobro <> nvl(v_new_fec_cobro, v_old_fec_cobro) OR
               nvl(p_tip_informe, 'x') = 'P' THEN
               BEGIN
                  SELECT mto_deuda
                    INTO v_new_mto_cuota
                    FROM co_inf_cob_personas
                   WHERE nro_cuenta = p_nro_cuenta
                     AND nro_cuota = 0;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_new_mto_cuota := NULL;
               END;
               IF nvl(v_new_mto_cobro, 0) > nvl(v_new_mto_cuota, 0) THEN
                  v_new_mto_cobro := nvl(v_new_mto_cuota, 0);
               END IF;
            END IF;
            /** Si es Préstamo. **/
         ELSIF p_cod_modulo = 6 THEN
            IF nvl(p_tip_informe, 'x') = 'P' /*AND
                                                                                                                                                                                                                                                            v_old_fec_cobro IN
                                                                                                                                                                                                                                                            (to_date('25/05/2006', 'dd/mm/yyyy'), to_date('26/05/2006', 'dd/mm/yyyy'))*/
             THEN
               BEGIN
                  SELECT MAX(c.fecha),
                         SUM(nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) +
                             nvl(c.mto_int_documentado, 0))
                    INTO v_new_fec_cobro, v_new_mto_cobro
                    FROM pr_cobros c
                   WHERE c.nro_cuenta = p_nro_cuenta
                     AND nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) +
                         nvl(c.mto_int_documentado, 0) > 0
                     AND c.fecha >= v_old_fec_cobro;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_new_fec_cobro := NULL;
                     v_new_mto_cobro := NULL;
               END;
            ELSE
               BEGIN
                  SELECT MAX(c.fecha),
                         SUM(nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) +
                             nvl(c.mto_int_documentado, 0))
                    INTO v_new_fec_cobro, v_new_mto_cobro
                    FROM pr_cobros c
                   WHERE c.nro_cuenta = p_nro_cuenta
                     AND c.nro_cuota >= p_nro_cuota
                     AND c.nro_cuota <= (nvl(p_nro_cuota, 0) + nvl(p_can_cuotas, 0) - 1)
                     AND c.fecha >= v_old_fec_cobro
                     AND nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) +
                         nvl(c.mto_int_documentado, 0) > 0;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_new_fec_cobro := NULL;
                     v_new_mto_cobro := NULL;
               END;
            END IF;
            IF v_old_fec_cobro <> nvl(v_new_fec_cobro, v_old_fec_cobro) OR
               nvl(p_tip_informe, 'x') = 'P' THEN
               BEGIN
                  SELECT mto_deuda
                    INTO v_new_mto_cuota
                    FROM co_inf_cob_personas
                   WHERE nro_cuenta = p_nro_cuenta
                     AND nro_cuota = p_nro_cuota;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_new_mto_cuota := NULL;
               END;

               IF nvl(v_new_mto_cobro, 0) > nvl(v_new_mto_cuota, 0) THEN
                  v_new_mto_cobro := nvl(v_new_mto_cuota, 0);
               END IF;
            END IF;
         END IF;
         IF nvl(v_new_mto_cobro, 0) <> 0 THEN
            IF nvl(v_new_mto_cobro, 0) = nvl(v_new_mto_cuota, 0) THEN
               p_tip_cobro := 'T';
            ELSE
               p_tip_cobro := 'P';
            END IF;
         ELSE
            p_tip_cobro := NULL;
         END IF;
         p_fec_ult_pago := v_new_fec_cobro;
         p_mto_ult_pago := v_new_mto_cobro;
      END lp_obt_pago;

      /** Obtiene el Nro de Tarjeta del Cliente. **/
      FUNCTION lf_obt_tarjeta
      (
         p_nro_cuenta  IN ta_cta_tarjetas.nro_cuenta%TYPE,
         p_observacion VARCHAR2,
         p_mensaje     OUT VARCHAR2
      ) RETURN VARCHAR2 IS
         v_nro_tarjeta ta_tarjetas.nro_tarjeta%TYPE;
      BEGIN
         BEGIN
            SELECT t.nro_tarjeta
              INTO v_nro_tarjeta
              FROM ta_tarjetas t, ge_cta_clientes c
             WHERE t.nro_cuenta = p_nro_cuenta
               AND t.nro_cuenta = c.nro_cuenta
               AND t.cod_persona = c.cod_persona
               AND nvl(c.relacion, 'x') = 'P'
               AND nvl(t.vigente, 'N') = 'S'
               AND rownum = 1;
         EXCEPTION
            WHEN no_data_found THEN
               BEGIN
                  /** Buscamos en tarjetas Vencidas. **/
                  SELECT t.nro_tarjeta
                    INTO v_nro_tarjeta
                    FROM ov_cta_vencidas a, ta_tarjetas t, ge_cta_clientes c
                   WHERE a.nro_cta_origen = t.nro_cuenta
                     AND t.nro_cuenta = c.nro_cuenta
                     AND t.cod_persona = c.cod_persona
                     AND a.nro_cuenta = p_nro_cuenta
                     AND nvl(c.relacion, 'x') = 'P'
                        --and nvl( t.vigente, 'N' ) = 'S'
                     AND rownum = 1;
                  --v_nro_tarjeta := NULL;
               EXCEPTION
                  /** Sino encuentra enviamos nro_cuenta(En el campo se puede enviar uno los dos datos a Informconf). **/
                  WHEN no_data_found THEN
                     v_nro_tarjeta := p_nro_cuenta;
               END;
            WHEN OTHERS THEN
               p_mensaje := 'Error al buscar la tarjeta para la cuenta ' || p_nro_cuenta || '; ' ||
                            SQLERRM;
         END;
         RETURN v_nro_tarjeta;
      EXCEPTION
         WHEN OTHERS THEN
            p_mensaje := 'Error en el proceso de busqueda de tarjetas para la cuenta ' ||
                         p_nro_cuenta || '; ' || SQLERRM;
            RETURN NULL;
      END;
      /**********************************************************************
      ********************* INICIO DE PROCESO PRINCIPAL *********************
      **********************************************************************/
   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
      /** Se verifica que no se corra 2 veces el proceso en el mismo dia. **/
      SELECT MAX(cd.fec_envio) INTO v_fec_control FROM co_inf_cob_diarios cd;
      IF trunc(v_fec_control) = trunc(c_fec_actual) THEN
         /** Para asegurar que no corran 2 veces el proceso en el mismo dia. **/
         raise_application_error(-20000,
                                 'Error Cobros de Fecha ' || to_char(c_fec_actual, 'DD/MM/YYYY') ||
                                  ' ya procesados. No se puede volver a procesar en el mismo día!');
      END IF;
      /** Busca los parámetros para el proceso. **/
      v_nro     := '1-Inicio';
      v_mensaje := NULL;
      BEGIN
         SELECT MAX(fec_envio) INTO v_fec_ult_env FROM co_inf_cob_diarios;
      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            v_mensaje := 'No se pudo obtener la fecha de último proceso para Informconf ' ||
                         SQLERRM;
            RAISE v_error;
      END;

      IF v_fec_ult_env IS NULL THEN
         /** La primera vez se toma desde el dia anterior. **/
         v_fec_ult_env := c_fec_actual;
      END IF;
      v_regs        := 0;
      v_old_nro_cta := NULL;
      v_old_nro_cuo := NULL;
      /** Cursor de Inclusiones para Informconf. **/
      v_nro := '3.11- Al buscar en el cursor de inclusiones';
      /** Cursor de Inclusiones para Informconf. **/
      FOR i IN inclusiones('N') LOOP
         v_nro := '3.12- Al ingresar al archivo de inclusiones';
         IF nvl(v_old_nro_cta, ' ') <> i.nro_cuenta OR nvl(v_old_nro_cuo, 0) <> i.nro_cuota THEN
            v_regs := nvl(v_regs, 0) + 1;
            v_nro  := '34-Obt. Direcciones';
            pre_obt_direccion(i.cod_persona, v_dir_par, v_dir_lab, v_dir_lab_alt);
            v_nro := '35-Obt. Telefonos';
            pre_obt_telefono(i.cod_persona, v_tel_par, v_tel_lab, v_tel_lab_alt);
            v_nro                         := '37- Ins. Datos';
            v_tip_cobro                   := NULL;
            v_fec_pago                    := i.fec_ult_pago;
            v_mto_pago                    := fup_obt_mto_cobrado(i.nro_cuenta,i.nro_cuota,i.fec_ult_pago);
            r_linea                       := NULL;
            r_linea.cod_persona           := i.cod_persona;
            r_linea.nro_cuenta            := i.nro_cuenta;
            r_linea.nro_cuota             := nvl(i.nro_cuota, 0);
            r_linea.cod_modulo            := i.cod_modulo;
            r_linea.cod_modalidad         := i.cod_modalidad;
            r_linea.cod_moneda            := i.cod_moneda;
            r_linea.nro_documento         := i.nro_documento;
            r_linea.pri_nombre            := i.pri_nombre;
            r_linea.seg_nombre            := i.seg_nombre;
            r_linea.pri_apellido          := i.pri_apellido;
            r_linea.seg_apellido          := i.seg_apellido;
            r_linea.ape_casada            := i.ape_casada;
            r_linea.dir_particular        := v_dir_par;
            r_linea.dir_laboral           := v_dir_lab;
            r_linea.dir_lab_alternativo   := v_dir_lab_alt;
            r_linea.tel_particular        := v_tel_par;
            r_linea.tel_laboral           := v_tel_lab;
            r_linea.tel_lab_alternativo   := v_tel_lab_alt;
            r_linea.fec_operacion         := i.fec_operacion;
            r_linea.can_cuotas            := i.can_cuotas;
            r_linea.tip_inf_operacion     := i.tip_operacion;
            r_linea.pri_cuo_atrasada      := i.pri_cuo_atrasada;
            r_linea.can_cuo_atrasada      := i.can_cuo_atrasada;
            r_linea.mto_cuota             := i.mto_cuota;
            r_linea.fec_vencimiento       := i.pri_fec_ven_atrasada;
            r_linea.fec_ult_pago          := i.fec_ult_pago;
            r_linea.tip_inf_garantia      := lf_obt_garantia(i.nro_cuenta, i.cod_modulo,
                                                             i.observacion);
            r_linea.tip_inf_moneda        := i.tip_moneda;
            r_linea.mto_deuda             := i.sal_mora;
            r_linea.fec_final             := i.fec_final;
            r_linea.tip_inf_cobro         := v_tip_cobro;
            r_linea.mto_cobrado           := v_mto_pago;
            r_linea.fec_cobro             := v_fec_pago;
            r_linea.tip_inf_actualizacion := NULL;
            r_linea.inf_periodicidad      := i.periodicidad;
            r_linea.observacion           := TRIM(i.observacion);
            r_linea.nro_cta_nueva         := i.nro_cta_nueva;
            r_linea.cod_ori_modulo        := i.cod_ori_modulo;
            r_linea.cod_ori_modalidad     := i.cod_ori_modalidad;
            r_linea.cod_sec_credito       := i.cod_sec_credito;

            IF r_linea.cod_modulo = 5 THEN
               r_linea.nro_tarjeta := lf_obt_tarjeta(r_linea.nro_cuenta, r_linea.observacion,
                                                     v_mensaje);
            END IF;
            /** Cargamos el monto de Sobregiro o el monto de Tarjeta Vencida. **/
            IF i.tip_operacion = 4 OR (i.cod_modulo = 5 AND i.observacion = 'INC-1.4') THEN
               /** Cargamos el total de la deuda(=mto_cuota), fec_vto=fec_ope en sobregiros. **/
               r_linea.mto_cuota       := i.sal_mora;
               r_linea.mto_deuda       := r_linea.mto_cuota;
               r_linea.fec_vencimiento := i.fec_operacion;
               r_linea.dia_atraso      := i.dias_atraso;
            END IF;

            BEGIN
               v_existe := 0;
               /** Verificamos si ya existe. **/
               BEGIN
                  SELECT COUNT(*)
                    INTO v_existe
                    FROM co_inf_cob_diarios w
                   WHERE trunc(w.fec_envio) = trunc(c_fec_actual)
                     AND w.cod_persona = r_linea.cod_persona
                     AND w.nro_cuenta = r_linea.nro_cuenta
                     AND w.nro_cuota = r_linea.nro_cuota
                     AND w.cod_modulo = r_linea.cod_modulo
                     AND w.cod_modalidad = r_linea.cod_modalidad
                     AND w.tip_envio = 'I';
               EXCEPTION
                  WHEN no_data_found THEN
                     v_existe := 0;
               END;
               IF v_existe = 0 THEN
                  v_nro := '37' || i.cod_persona;
                  pao_cob.pr_gen_inf_linea(r_linea, 'I');
               END IF;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  v_mensaje := 'Se produjo un error al generar la línea ' || SQLERRM;
                  RAISE v_error;
            END;
         END IF;
         r_linea.nro_cuota := i.nro_cuota;
         v_nro             := '38-Borra co_inf_cob_personas';
         /** Buscamos si no existe aun en co_inf_cob_personas, de no ser asi insertamos. **/
         v_existe := 0;
         BEGIN
            SELECT COUNT(*)
              INTO v_existe
              FROM co_inf_cob_personas a
             WHERE a.cod_persona = r_linea.cod_persona
               AND a.nro_cuenta = r_linea.nro_cuenta
               AND a.nro_cuota = r_linea.nro_cuota;
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 0;
         END;

         IF v_existe = 0 THEN
            BEGIN
               INSERT INTO co_inf_cob_personas
                  (cod_usu_gestion, cod_persona, nro_cuenta, nro_cuota, cod_modulo, cod_modalidad,
                   cod_moneda, fec_ini_envio, nro_documento, pri_nombre, seg_nombre, pri_apellido,
                   seg_apellido, ape_casada, dir_particular, dir_laboral, dir_lab_alternativo,
                   tel_particular, tel_laboral, tel_lab_alternativo, fec_operacion, can_cuotas,
                   tip_inf_operacion, pri_cuo_atrasada, can_cuo_atrasada, mto_cuota, fec_vencimiento,
                   fec_ult_pago, tip_inf_garantia, tip_inf_moneda, mto_deuda, fec_final,
                   tip_inf_cobro, mto_cobrado, fec_cobro, tip_inf_actualizacion, inf_periodicidad,
                   nro_tarjeta, observacion, nro_cta_nueva, cod_ori_modulo, cod_ori_modalidad,
                   cod_sec_credito)
               VALUES
                  (r_linea.cod_usu_gestion, r_linea.cod_persona, r_linea.nro_cuenta,
                   r_linea.nro_cuota, r_linea.cod_modulo, r_linea.cod_modalidad, r_linea.cod_moneda,
                   c_fec_actual, r_linea.nro_documento, r_linea.pri_nombre, r_linea.seg_nombre,
                   r_linea.pri_apellido, r_linea.seg_apellido, r_linea.ape_casada,
                   r_linea.dir_particular, r_linea.dir_laboral, r_linea.dir_lab_alternativo,
                   r_linea.tel_particular, r_linea.tel_laboral, r_linea.tel_lab_alternativo,
                   r_linea.fec_operacion, r_linea.can_cuotas, r_linea.tip_inf_operacion,
                   r_linea.pri_cuo_atrasada, r_linea.can_cuo_atrasada, r_linea.mto_cuota,
                   r_linea.fec_vencimiento, r_linea.fec_ult_pago, r_linea.tip_inf_garantia,
                   r_linea.tip_inf_moneda, r_linea.mto_deuda, r_linea.fec_final,
                   r_linea.tip_inf_cobro, r_linea.mto_cobrado, r_linea.fec_cobro,
                   r_linea.tip_inf_actualizacion, r_linea.inf_periodicidad, r_linea.nro_tarjeta,
                   TRIM(r_linea.observacion), r_linea.nro_cta_nueva, r_linea.cod_ori_modulo,
                   r_linea.cod_ori_modalidad,r_linea.cod_sec_credito);
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  v_mensaje := 'No se pudo insertar la cuenta ' || r_linea.nro_cuenta || '/' ||
                               to_char(r_linea.nro_cuota) || '; ' || SQLERRM;
                  RAISE v_error;
            END;
         END IF;
         v_nro         := '39';
         v_old_nro_cta := i.nro_cuenta;
         v_old_nro_cuo := i.nro_cuota;
      END LOOP;
      /**************** FIN DE CURSOR DE INCLUSIONES ****************/

      v_nro         := '2-Antes Cur.Modif.';
      v_old_nro_cta := NULL;
      v_old_nro_cuo := NULL;
      /***************** Cursor de Modificaciones para Informconf *****************/
      FOR m IN modificaciones LOOP
         IF nvl(v_old_nro_cta, ' ') <> m.nro_cuenta OR nvl(v_old_nro_cuo, 0) <> m.nro_cuota THEN
            IF nvl(r_linea.tip_inf_actualizacion, 'x') = 'P'
            --AND  NOT ((m.cod_modulo= 4) or (m.cod_modulo =5 and m.observacion ='MOD-1.5') or (m.observacion ='MOD-1.7'))
             THEN
               v_nro := '27.1-Al borrar co_inf_cob_personas';
               BEGIN
                  DELETE co_inf_cob_personas
                   WHERE cod_persona = r_linea.cod_persona
                     AND nro_cuenta = r_linea.nro_cuenta
                        --********************************
                     AND cod_modulo = r_linea.cod_modulo
                     AND nro_cuota = r_linea.nro_cuota;
                  /** Se modifica porque nro_cuota = 0 en tarjetas y sobregiro. **/
                  --and tip_inf_operacion= r_linea.tip_inf_operacion;
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     v_mensaje := 'No se pudo eliminar la cuenta ' || r_linea.nro_cuenta || '; ' ||
                                  SQLERRM;
                     RAISE v_error;
               END;
               v_nro := '27.2-Al Insertar pro_gen_inf_linea';
            END IF;
            IF v_old_nro_cta IS NOT NULL THEN
               BEGIN
                  pao_cob.pr_gen_inf_linea(r_linea, 'M');
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     v_mensaje := 'Se produjo un error al generar la línea al:' || v_nro || '-' ||
                                  SQLERRM;
                     RAISE v_error;
               END;
            END IF;
            r_linea := NULL;
            v_nro   := '20-Obt. Direcc.';
            pre_obt_direccion(m.cod_persona, v_dir_par, v_dir_lab, v_dir_lab_alt);
            v_nro := '21-Obt. Tel';
            pre_obt_telefono(m.cod_persona, v_tel_par, v_tel_lab, v_tel_lab_alt);
            v_nro                    := '22-Obt.Tip.Garantia';
            r_linea.tip_inf_garantia := lf_obt_garantia(m.nro_cuenta, m.cod_modulo, m.observacion);
         END IF;
         v_nro := '22-Obt.Pago';
         /** Obtenemos los datos del cobro (Si es préstamo o tarjeta). **/
         IF (m.cod_modulo = 6) OR
            (m.cod_modulo = 5 AND m.observacion NOT IN ('MOD-1.5', 'MOD-1.9')) THEN
            /** Modificado para incluir cantidad de cuotas que debía. **/
            lp_obt_pago(m.nro_cuenta, m.nro_cuota, m.cod_modulo, v_tip_cobro, v_fec_pago,
                        v_mto_pago, m.tip_actualizacion, m.can_cuo_atrasada);
         ELSIF (m.cod_modulo = 4) OR (m.cod_modulo = 5 AND m.observacion = 'MOD-1.5') OR
               (m.observacion = 'MOD-1.7') OR (m.observacion = 'MOD-1.9') THEN
            /** Si es de Sobregiros o Tarjetas Vencidas. **/
            IF (m.observacion <> 'MOD-1.6') AND NOT m.observacion IN ('MOD-1.7', 'MOD-1.9') THEN
               /** Si es de Sobregiros o Tarjetas Vencidas verificamos el estado de la cuenta en ov_cta_vencidas. **/
               SELECT s.estado
                 INTO v_estado
                 FROM ov_cta_vencidas s
                WHERE s.nro_cta_origen = m.nro_cuenta;

               IF v_estado = 'C' THEN
                  /** Pagó todo el Sobregiro o la Tarjeta Vencida. **/
                  v_tip_cobro := 'T';
                  v_mto_pago  := m.mto_cuota;
               ELSE
                  /** Pagó parte del Sobregiro o Tarjeta Vencida. **/
                  v_tip_cobro := 'P';
                  /** Obtenemos lo que pago. **/
                  SELECT nvl(w.mto_total, 0)
                    INTO v_mto_pagado
                    FROM ov_cobros w
                   WHERE w.nro_cuenta = m.nro_cta_nueva
                     AND trunc(w.fecha) = trunc(c_fec_actual)
                     AND rownum = 1;

                  /** El monto pagado es el monto que debia - Sal_total(Lo que debe actualmente). **/
                  v_mto_pago := nvl(v_mto_pagado, 0); --nvl(m.mto_cuota,0) - nvl(v_mto_pagado,0);
               END IF;
               v_fec_pago := c_fec_actual;

            ELSIF m.observacion = 'MOD-1.6' THEN
               v_nro := 'VOY A OBTENER 2:' || m.observacion;
               /***** Aqui ingresa si es es Cta. Cte. *****/
               /** Verificamos el estado de la cuenta en cc_cta_corrientes. **/
               SELECT nvl(r.can_dias, 0)
                 INTO v_nro_1
                 FROM cc_cta_corrientes s, cc_sobregiros_res r
                WHERE s.nro_cuenta = m.nro_cuenta
                  AND s.nro_cuenta = r.nro_cuenta(+);

               IF v_nro_1 = 0 THEN
                  /** Pagó toda la deuda de CC_CTA_CORRIENTES. **/
                  v_tip_cobro := 'T';
                  v_mto_pago  := m.mto_cuota;
               ELSE
                  /** Pagó parte de su CC_CTA_CORRIENTES. **/
                  v_tip_cobro := 'P';
                  /** Obtenemos el saldo actual de la cuenta. **/
                  SELECT nvl(abs(w.sal_total), 0)
                    INTO v_mto_pagado
                    FROM cc_cta_corrientes w
                   WHERE w.nro_cuenta = m.nro_cuenta
                     AND rownum = 1;
                  /** El monto pagado es el monto que debia - Sal_total(Lo que debe actualmente). **/
                  v_mto_pago := nvl(m.mto_cuota, 0) - nvl(v_mto_pagado, 0);
               END IF;
               v_fec_pago := c_fec_actual;

            ELSIF m.observacion = 'MOD-1.7' THEN
               /***** Aquí ingresa si es Cta. Cte. y se aumenta su deuda. *****/
               /** Pagó parte de su CC_CTA_CORRIENTES. **/
               v_tip_cobro := 'P';
               /** Obtenemos el saldo actual de la cuenta. Buscamos el nuevo monto de mora. **/
               SELECT nvl(abs(r.mto_mora), 0)
                 INTO v_mto_pagado
                 FROM cc_cta_corrientes w, cc_sobregiros_res r
                WHERE w.nro_cuenta = m.nro_cuenta
                  AND w.nro_cuenta = r.nro_cuenta(+)
                  AND rownum = 1;
               /** El monto pagado es lo que se le va a enviar como 'D'. **/
               v_mto_pago := nvl(v_mto_pagado, 0);
               v_fec_pago := NULL;

            ELSIF m.observacion = 'MOD-1.9' THEN
               /** Aquí ingresa si ya se envio como cuenta corriente o tarjeta y al pasar a vencidas aumento su deuda. **/
               v_tip_cobro := 'P';
               /** Buscamos el nuevo saldo total. **/
               SELECT nvl(abs(w.sal_total), 0)
                 INTO v_mto_pagado
                 FROM ov_cta_vencidas w
                WHERE w.nro_cta_origen = m.nro_cuenta
                  AND rownum = 1;
               /** El monto pagado es lo que se le va a enviar como 'D'. **/
               v_mto_pago := nvl(v_mto_pagado, 0);
               v_fec_pago := NULL;
            END IF;
            /** Fin de verificación. **/
         END IF;
         v_nro                       := '23-Insertar Linea';
         r_linea.cod_persona         := m.cod_persona;
         r_linea.nro_cuenta          := m.nro_cuenta;
         r_linea.nro_cuota           := m.nro_cuota;
         r_linea.cod_modulo          := m.cod_modulo;
         r_linea.cod_modalidad       := m.cod_modalidad;
         r_linea.cod_moneda          := m.cod_moneda;
         r_linea.nro_documento       := m.nro_documento;
         r_linea.pri_nombre          := m.pri_nombre;
         r_linea.seg_nombre          := m.seg_nombre;
         r_linea.pri_apellido        := m.pri_apellido;
         r_linea.seg_apellido        := m.seg_apellido;
         r_linea.ape_casada          := m.ape_casada;
         r_linea.dir_particular      := v_dir_par;
         r_linea.dir_laboral         := v_dir_lab;
         r_linea.dir_lab_alternativo := v_dir_lab_alt;
         r_linea.tel_particular      := v_tel_par;
         r_linea.tel_laboral         := v_tel_lab;
         r_linea.tel_lab_alternativo := v_tel_lab_alt;
         r_linea.fec_operacion       := m.fec_operacion;
         r_linea.can_cuotas          := m.can_cuotas;
         r_linea.tip_inf_operacion   := m.tip_operacion;
         r_linea.pri_cuo_atrasada    := m.pri_cuo_atrasada;
         r_linea.can_cuo_atrasada    := m.can_cuo_atrasada;
         r_linea.mto_cuota           := m.mto_cuota;
         r_linea.fec_vencimiento     := m.pri_fec_ven_atrasada;
         r_linea.fec_ult_pago        := m.fec_ult_pago;
         r_linea.tip_inf_moneda      := m.tip_moneda;
         IF ((m.cod_modulo = 4) OR (m.cod_modulo = 5 AND m.observacion = 'MOD-1.5')) AND
            m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            IF m.sal_mora = nvl(v_mto_pago, 0) THEN
               r_linea.mto_deuda := 0;
            ELSE
               r_linea.mto_deuda := nvl(m.sal_mora, 0) - nvl(v_mto_pago, 0);
               r_linea.mto_cuota := nvl(m.sal_mora, 0) - nvl(v_mto_pago, 0);
            END IF;
         ELSIF m.observacion IN ('MOD-1.7', 'MOD-1.9') THEN
            r_linea.mto_deuda := nvl(v_mto_pago, 0);
            r_linea.mto_cuota := nvl(v_mto_pago, 0);
         ELSIF ((m.cod_modulo = 6) OR (m.cod_modulo = 5 AND m.observacion <> 'MOD-1.5')) AND
               m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            IF nvl(m.sal_mora, 0) = nvl(v_mto_pago, 0) THEN
               r_linea.mto_deuda := 0;
            ELSE
               r_linea.mto_deuda := nvl(m.sal_mora, 0) - nvl(v_mto_pago, 0);
               r_linea.mto_cuota := nvl(m.sal_mora, 0) - nvl(v_mto_pago, 0);
            END IF;
         END IF;
         IF (m.cod_modulo = 6) AND m.observacion IN ('MOD-1.3', 'MOD-1.1') THEN
            /** Obtenemos el monto de Cuota de la tabla pr_cuotas acorde a la nueva cuota enviada. **/
            BEGIN
               SELECT nvl(u.mto_capital, 0) + nvl(u.mto_interes, 0)
                 INTO r_linea.mto_cuota
                 FROM pr_cuotas u
                WHERE u.nro_cuota = m.nro_cuota
                  AND u.nro_cuenta = m.nro_cuenta;
            EXCEPTION
               WHEN no_data_found THEN
                  r_linea.mto_cuota := r_linea.mto_cuota;
            END;
         END IF;

         r_linea.fec_final        := m.fec_final;
         r_linea.tip_inf_cobro    := v_tip_cobro;
         r_linea.fec_cobro        := v_fec_pago;
         r_linea.inf_periodicidad := m.periodicidad;
         r_linea.observacion      := TRIM(m.observacion);
         IF (m.cod_modulo = 5 OR m.cod_modulo = 6) AND m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            r_linea.dia_atraso := nvl(m.dias_atraso, 0);
         END IF;
         IF r_linea.nro_tarjeta IS NULL AND r_linea.cod_modulo = 5 THEN
            /** Debe de buscar la tarjeta en ambos criterios. **/
            --and m.observacion not IN ('MOD-1.7','MOD-1.9')THEN
            r_linea.nro_tarjeta := lf_obt_tarjeta(r_linea.nro_cuenta, r_linea.observacion, v_mensaje);
         END IF;
         IF (m.cod_modulo = 6) OR (m.cod_modulo = 5 AND m.observacion <> 'MOD-1.5') AND
            m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            --r_linea.cod_modulo in (5,6) then
            IF nvl(m.tip_actualizacion, 'x') = 'P' THEN
               r_linea.tip_inf_actualizacion := 'P';
               r_linea.mto_cobrado           := nvl(r_linea.mto_cobrado, 0) + nvl(v_mto_pago, 0);
            ELSE
               r_linea.tip_inf_actualizacion := 'D';
               r_linea.mto_cobrado           := v_mto_pago;
            END IF;
         ELSIF (m.cod_modulo = 4 OR (m.cod_modulo = 5 AND m.observacion = 'MOD-1.5')) AND
               m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            --else
            /** Si es Sobregiros. **/
            r_linea.tip_inf_actualizacion := 'P';
            r_linea.mto_cobrado           := v_mto_pago;
         ELSIF m.observacion IN ('MOD-1.7', 'MOD-1.9') THEN
            r_linea.tip_inf_actualizacion := 'D';
            r_linea.mto_cobrado           := 0;
            r_linea.fec_ult_pago          := NULL;
            r_linea.mto_cobrado           := NULL;
            r_linea.nro_cta_nueva         := m.nro_cta_nueva;
            r_linea.dia_atraso            := m.dias_atraso;
         END IF;

         v_nro := '24-Update de co_inf_cob_personas';
         IF nvl(m.tip_actualizacion, 'x') <> 'P' THEN
            BEGIN
               UPDATE co_inf_cob_personas
                  SET cod_usu_gestion       = r_linea.cod_usu_gestion,
                      cod_persona           = r_linea.cod_persona,
                      nro_cuenta            = r_linea.nro_cuenta,
                      nro_cuota             = r_linea.nro_cuota,
                      cod_modulo            = r_linea.cod_modulo,
                      cod_modalidad         = r_linea.cod_modalidad,
                      cod_moneda            = r_linea.cod_moneda,
                      nro_documento         = r_linea.nro_documento,
                      pri_nombre            = r_linea.pri_nombre,
                      seg_nombre            = r_linea.seg_nombre,
                      pri_apellido          = r_linea.pri_apellido,
                      seg_apellido          = r_linea.seg_apellido,
                      ape_casada            = r_linea.ape_casada,
                      dir_particular        = r_linea.dir_particular,
                      dir_laboral           = r_linea.dir_laboral,
                      dir_lab_alternativo   = r_linea.dir_lab_alternativo,
                      tel_particular        = r_linea.tel_particular,
                      tel_laboral           = r_linea.tel_laboral,
                      tel_lab_alternativo   = r_linea.tel_lab_alternativo,
                      fec_operacion         = r_linea.fec_operacion,
                      can_cuotas            = r_linea.can_cuotas,
                      tip_inf_operacion     = r_linea.tip_inf_operacion,
                      pri_cuo_atrasada      = r_linea.pri_cuo_atrasada,
                      can_cuo_atrasada      = r_linea.can_cuo_atrasada,
                      mto_cuota             = r_linea.mto_cuota,
                      fec_vencimiento       = r_linea.fec_vencimiento,
                      fec_ult_pago          = r_linea.fec_ult_pago,
                      tip_inf_garantia      = r_linea.tip_inf_garantia,
                      tip_inf_moneda        = r_linea.tip_inf_moneda,
                      mto_deuda             = r_linea.mto_deuda,
                      fec_final             = r_linea.fec_final,
                      tip_inf_cobro         = r_linea.tip_inf_cobro,
                      mto_cobrado           = r_linea.mto_cobrado,
                      fec_cobro             = r_linea.fec_cobro,
                      tip_inf_actualizacion = r_linea.tip_inf_actualizacion,
                      inf_periodicidad      = r_linea.inf_periodicidad,
                      nro_tarjeta           = r_linea.nro_tarjeta,
                      observacion           = TRIM(r_linea.observacion),
                      dia_atraso            = nvl(r_linea.dia_atraso, 0),
                      nro_cta_nueva         = r_linea.nro_cta_nueva,
                      cod_sec_credito       = r_linea.cod_sec_credito
                WHERE cod_persona = r_linea.cod_persona
                  AND nro_cuenta = r_linea.nro_cuenta
                  AND nro_cuota = r_linea.nro_cuota;

               IF SQL%NOTFOUND THEN
                  v_nro := '26- Insertar en co_inf_cob_personas';
                  BEGIN
                     INSERT INTO co_inf_cob_personas
                        (cod_usu_gestion, cod_persona, nro_cuenta, nro_cuota, cod_modulo,
                         cod_modalidad, cod_moneda, fec_ini_envio, nro_documento, pri_nombre,
                         seg_nombre, pri_apellido, seg_apellido, ape_casada, dir_particular,
                         dir_laboral, dir_lab_alternativo, tel_particular, tel_laboral,
                         tel_lab_alternativo, fec_operacion, can_cuotas, tip_inf_operacion,
                         pri_cuo_atrasada, can_cuo_atrasada, mto_cuota, fec_vencimiento,
                         fec_ult_pago, tip_inf_garantia, tip_inf_moneda, mto_deuda, fec_final,
                         tip_inf_cobro, mto_cobrado, fec_cobro, tip_inf_actualizacion,
                         inf_periodicidad, nro_tarjeta, dia_atraso, observacion, nro_cta_nueva,
                         cod_ori_modulo, cod_ori_modalidad,cod_sec_credito)
                     VALUES
                        (r_linea.cod_usu_gestion, r_linea.cod_persona, r_linea.nro_cuenta,
                         r_linea.nro_cuota, r_linea.cod_modulo, r_linea.cod_modalidad,
                         r_linea.cod_moneda, c_fec_actual, r_linea.nro_documento, r_linea.pri_nombre,
                         r_linea.seg_nombre, r_linea.pri_apellido, r_linea.seg_apellido,
                         r_linea.ape_casada, r_linea.dir_particular, r_linea.dir_laboral,
                         r_linea.dir_lab_alternativo, r_linea.tel_particular, r_linea.tel_laboral,
                         r_linea.tel_lab_alternativo, r_linea.fec_operacion, r_linea.can_cuotas,
                         r_linea.tip_inf_operacion, r_linea.pri_cuo_atrasada,
                         r_linea.can_cuo_atrasada, r_linea.mto_cuota, r_linea.fec_vencimiento,
                         r_linea.fec_ult_pago, r_linea.tip_inf_garantia, r_linea.tip_inf_moneda,
                         r_linea.mto_deuda, r_linea.fec_final, r_linea.tip_inf_cobro,
                         r_linea.mto_cobrado, r_linea.fec_cobro, r_linea.tip_inf_actualizacion,
                         r_linea.inf_periodicidad, r_linea.nro_tarjeta, r_linea.dia_atraso,
                         TRIM(r_linea.observacion), r_linea.nro_cta_nueva, r_linea.cod_ori_modulo,
                         r_linea.cod_ori_modalidad,r_linea.cod_sec_credito);
                  EXCEPTION
                     WHEN v_error THEN
                        RAISE v_error;
                     WHEN OTHERS THEN
                        v_mensaje := 'Lugar:' || v_nro || '-' || 'No se pudo insertar la cuenta ' ||
                                     r_linea.nro_cuenta || '/' || to_char(r_linea.nro_cuota) || '; ' ||
                                     SQLERRM;
                        RAISE v_error;
                  END;
               END IF;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  v_mensaje := 'Lugar:' || v_nro || '-' || 'No se pudo actualizar la cuenta ' ||
                               r_linea.nro_cuenta || '/' || to_char(r_linea.nro_cuota) || '; ' ||
                               SQLERRM;
                  RAISE v_error;
            END;
         END IF;
         /** Borramos los Sobregiros. **/
         IF (r_linea.cod_modulo = 4 AND nvl(r_linea.tip_inf_actualizacion, 'X') = 'P') THEN
            DELETE co_inf_cob_personas
             WHERE cod_persona = r_linea.cod_persona
               AND nro_cuenta = r_linea.nro_cuenta
               AND nro_cuota = r_linea.nro_cuota
                  /** Se modifica porque nro_cuota=0 en tarjetas y sobregiro. **/
               AND tip_inf_operacion = r_linea.tip_inf_operacion;
         ELSIF (r_linea.cod_modulo = 6 AND nvl(r_linea.tip_inf_actualizacion, 'X') = 'D') THEN
            v_cantidad := 9999;
            BEGIN
               SELECT COUNT(*)
                 INTO v_cantidad
                 FROM co_inf_cob_diarios x
                WHERE x.nro_cuenta = r_linea.nro_cuenta
                  AND x.tip_envio = 'M'
                  AND x.observacion = 'MOD-1.3'
                  AND x.fec_envio = r_linea.fec_operacion;
            EXCEPTION
               WHEN no_data_found THEN
                  v_cantidad := 9999;
            END;
            IF v_cantidad <> 9999 THEN
               DELETE FROM co_inf_cob_diarios x
                WHERE x.nro_cuenta = r_linea.nro_cuenta
                  AND x.tip_envio = 'M'
                  AND x.observacion = 'MOD-1.3'
                  AND x.tip_inf_actualizacion = 'P'
                  AND x.fec_envio = r_linea.fec_operacion;
            END IF;
         END IF;
         v_old_nro_cta := m.nro_cuenta;
         v_old_nro_cuo := m.nro_cuota;
      END LOOP;
      /********************** Fin de Cursor de Modificación **********************/
      IF (nvl(r_linea.tip_inf_actualizacion, 'x') = 'P')
      --or  ((r_linea.cod_modulo=4 OR (r_linea.cod_modulo =5 and r_linea.observacion ='MOD-1.5'))))
      --and r_linea.tip_inf_cobro='T'
       THEN
         v_nro := '27- Al Borrar co_inf_cob_personas ';
         BEGIN
            DELETE co_inf_cob_personas
             WHERE cod_persona = r_linea.cod_persona
               AND nro_cuenta = r_linea.nro_cuenta
               AND nro_cuota = r_linea.nro_cuota
                  /** nro_cuota = 0 para Sobregiro y Tarjetas. **/
               AND tip_inf_operacion = r_linea.tip_inf_operacion;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               v_mensaje := 'No se pudo eliminar la cuenta ' || r_linea.nro_cuenta || '; ' ||
                            SQLERRM;
               RAISE v_error;
         END;
      END IF;
      IF v_old_nro_cta IS NOT NULL THEN
         BEGIN
            pr_gen_inf_linea(r_linea, 'M');
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               v_mensaje := 'Se produjo un error al generar la línea ' || SQLERRM;
               RAISE v_error;
         END;
      END IF;
      /** Eliminar para informar como incluidas las cuotas de cuentas informadas en modificación por cobro. **/
      BEGIN
         IF (nvl(r_linea.tip_inf_actualizacion, 'x') = 'P') THEN
            DELETE co_inf_cob_personas e
             WHERE e.nro_cuota > (SELECT MAX(nro_cuota)
                                    FROM co_inf_cob_diarios d
                                   WHERE e.nro_cuenta = d.nro_cuenta
                                     AND d.fec_envio = c_fec_actual
                                     AND e.cod_modulo = d.cod_modulo
                                     AND e.tip_inf_operacion = d.tip_inf_operacion);
         END IF;
      END;

      v_nro := '3- Al ingresar en el archivo de exclusiones';
      /***************** Cursor de Exclusiones para Informconf *****************/
      FOR e IN exclusiones LOOP
         v_nro := '8-Obt.  Direcciones';
         /** Obtiene la Dirección Particular, Laboral y Laboral Alternativa del Cliente. **/
         pre_obt_direccion(e.cod_persona, v_dir_par, v_dir_lab, v_dir_lab_alt);
         v_nro := '9-Obt. Telefonos';
         /** Obtiene el Nro. de Teléfono Particular, Laboral y Laboral Alternativa del Cliente. **/
         pre_obt_telefono(e.cod_persona, v_tel_par, v_tel_lab, v_tel_lab_alt);
         v_nro                         := '10-Ins. Linea';
         r_linea                       := NULL;
         r_linea.cod_persona           := e.cod_persona;
         r_linea.nro_cuenta            := e.nro_cuenta;
         r_linea.nro_cuota             := e.nro_cuota;
         r_linea.cod_modulo            := e.cod_modulo;
         r_linea.cod_modalidad         := e.cod_modalidad;
         r_linea.cod_moneda            := e.cod_moneda;
         r_linea.nro_documento         := e.nro_documento;
         r_linea.pri_nombre            := e.pri_nombre;
         r_linea.seg_nombre            := e.seg_nombre;
         r_linea.pri_apellido          := e.pri_apellido;
         r_linea.seg_apellido          := e.seg_apellido;
         r_linea.ape_casada            := e.ape_casada;
         r_linea.dir_particular        := v_dir_par;
         r_linea.dir_laboral           := v_dir_lab;
         r_linea.dir_lab_alternativo   := v_dir_lab_alt;
         r_linea.tel_particular        := v_tel_par;
         r_linea.tel_laboral           := v_tel_lab;
         r_linea.tel_lab_alternativo   := v_tel_lab_alt;
         r_linea.fec_operacion         := e.fec_operacion;
         r_linea.can_cuotas            := e.can_cuotas;
         r_linea.tip_inf_operacion     := e.tip_inf_operacion;
         r_linea.pri_cuo_atrasada      := e.pri_cuo_atrasada;
         r_linea.can_cuo_atrasada      := e.can_cuo_atrasada;
         r_linea.mto_cuota             := e.mto_cuota;
         r_linea.fec_vencimiento       := e.fec_vencimiento;
         r_linea.fec_ult_pago          := e.fec_ult_pago;
         r_linea.tip_inf_garantia      := e.tip_inf_garantia;
         r_linea.tip_inf_moneda        := e.tip_inf_moneda;
         r_linea.mto_deuda             := e.mto_deuda;
         r_linea.fec_final             := e.fec_final;
         r_linea.tip_inf_cobro         := NULL;
         r_linea.mto_cobrado           := e.mto_cobrado;
         r_linea.fec_cobro             := e.fec_cobro;
         r_linea.tip_inf_actualizacion := NULL;
         r_linea.inf_periodicidad      := e.inf_periodicidad;
         r_linea.nro_tarjeta           := e.nro_tarjeta;
         r_linea.observacion           := TRIM(e.observacion);

         BEGIN
            pao_cob.pr_gen_inf_linea(r_linea, 'E');
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               v_mensaje := 'Se produjo un error al generar la línea ' || SQLERRM;
               RAISE v_error;
         END;
         v_nro := '12-Borrar co_inf_cob_personas';
         BEGIN
            DELETE co_inf_cob_personas
             WHERE cod_persona = r_linea.cod_persona
               AND nro_cuenta = r_linea.nro_cuenta
               AND cod_modulo = r_linea.cod_modulo
               AND nro_cuota = r_linea.nro_cuota;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               v_mensaje := 'No se pudo eliminar la cuenta ' || r_linea.nro_cuenta || '/' ||
                            to_char(r_linea.nro_cuota) || '; ' || SQLERRM;
               RAISE v_error;
         END;
      END LOOP;

      v_nro := '40';
      BEGIN
         SELECT COUNT(DISTINCT(cod_persona)) INTO v_can_inf FROM co_inf_cob_personas;
      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            v_can_inf := 0;
      END;
      v_nro         := '48';
      v_can_sol     := 0;
      v_nro         := '49';
      v_regs        := 0;
      v_old_nro_cta := NULL;
      v_old_nro_cuo := NULL;
      /******************* FIN DE PROCESO PRINCIPAL *******************/

      v_nro := '61- Al gen. Ascii';
      /** En la linea inferior llama al Procedimiento que genera el archivo ASCII a ser enviado. **/
      /*IF v_mensaje IS NULL THEN
         pr_gen_inf_archivo;
      END IF;*/
   EXCEPTION
      WHEN v_error THEN
         raise_application_error(-20852, 'ITC-' || ': (' || to_char(v_regs) || ') ' || v_mensaje);
      WHEN OTHERS THEN
         raise_application_error(-20853,
                                 'ITC-' || ': (' || to_char(v_regs) || ') ' ||
                                  'Error en el proceso de control de cobranzas --Nro:' || v_nro || '-' ||
                                  SQLERRM);
   END pr_gen_inf_arc_cob;

   /** Informconf- Lee de co_inf_cob_diarios y luego genera el ascii. **/
   PROCEDURE pr_gen_inf_archivo(p_fec_envio IN DATE DEFAULT NULL) IS
      /**
      || EFECTUA      : Proceso encargado de generar los archivos para enviar a Informconf la
      ||                información necesaria para la Gestión de Cobros por cuentas.
      ||                A la fecha son 3 archivos que se envían: Inclusión, Modificación y Exclusión,
      ||                los cuales tienen el mismo formato entre sí.
      ||                Se generan 2 juegos de archivos, uno para cuentas con días de mora hasta 180 días,
      ||                y otro para los que tengan más de 180 días de mora.
      **/
      /**************************** VARIABLES LOCALES ****************************/
      v_nom_archivo VARCHAR2(100);
      --Fecha actual del Módulo de Cobranzas
      c_fec_actual    DATE default fuo_fec_strategy;
      v_archivo     utl_file.file_type;
      v_procesar    BOOLEAN;
      v_old_nro_cta ge_cuentas.nro_cuenta%TYPE;
      v_old_nro_cuo co_inf_cob_diarios.nro_cuota%TYPE;
      v_cod_afi     NUMBER(10);
      v_tip_envio   VARCHAR2(1);
      v_buffer      VARCHAR2(9000);
      v_fec_ope     DATE;
      v_tip_inf_mon VARCHAR2(2);
      v_nro         NUMBER;
      v_regs        NUMBER;
      v_mensaje     VARCHAR2(2000);
      v_error EXCEPTION;
      v_cod_operacion VARCHAR2(20);
      e               NUMBER := 0;
      conn            utl_smtp.connection;

      CURSOR datos(p_tip_envio VARCHAR2) IS
         SELECT o.cod_persona,
                o.nro_cuenta,
                o.nro_cuota,
                o.nro_documento,
                REPLACE(substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65),
                        chr(9), '') pri_nombre,
                REPLACE(substr(f.seg_nombre, 1, 15), chr(9), '') seg_nombre,
                REPLACE(substr(f.pri_apellido, 1, 20), chr(9), '') pri_apellido,
                REPLACE(substr(f.seg_apellido, 1, 20), chr(9), '') seg_apellido,
                NULL ape_casada,
                o.dir_particular,
                o.dir_laboral,
                o.dir_lab_alternativo,
                o.tel_particular,
                o.tel_laboral,
                o.tel_lab_alternativo,
                o.can_cuotas,
                o.tip_inf_operacion,
                o.pri_cuo_atrasada,
                o.can_cuo_atrasada,
                o.mto_cuota,
                o.fec_vencimiento,
                o.fec_ult_pago,
                o.nro_tarjeta,
                o.tip_inf_garantia,
                o.mto_deuda,
                o.fec_final,
                o.tip_inf_cobro,
                o.mto_cobrado,
                o.fec_cobro,
                o.tip_inf_actualizacion,
                o.inf_periodicidad,
                o.cod_modulo,
                o.cod_modalidad,
                o.cod_moneda,
                o.observacion
           FROM co_inf_cob_diarios o, ba_per_fisicas f, ba_per_juridicas j
          WHERE o.fec_envio = nvl(p_fec_envio, c_fec_actual)
            AND o.tip_envio = p_tip_envio
            AND o.cod_persona = f.cod_persona(+)
            AND o.cod_persona = j.cod_persona(+)
          ORDER BY substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65),
                   substr(f.seg_nombre, 1, 15),
                   substr(f.pri_apellido, 1, 20),
                   substr(f.seg_apellido, 1, 20),
                   o.nro_cuenta,
                   o.nro_cuota;
      r_datos datos%ROWTYPE;
      ----
      PROCEDURE lp_carga_datos
      (
         p_nro_cta     IN VARCHAR2,
         p_cod_mod     IN NUMBER,
         p_cod_mon     IN VARCHAR2,
         p_observacion IN VARCHAR2,
         p_fec_ope     OUT DATE,
         p_inf_mon     OUT VARCHAR2,
         p_error       OUT VARCHAR2
      ) IS
         v_fec DATE;
         v_mon VARCHAR2(10);
         v_err VARCHAR2(2000);
      BEGIN
         /** Si es tarjeta Normal. **/
         IF p_cod_mod = 5 AND p_observacion IN ('INC-1.2', 'MOD-1.2') THEN
            BEGIN
               SELECT fec_apertura INTO v_fec FROM ta_cta_tarjetas WHERE nro_cuenta = p_nro_cta;
            EXCEPTION
               WHEN OTHERS THEN
                  v_err := 'Error al buscar la fecha de apertura de la cuenta(ta_cta_tarjetas) ' ||
                           p_nro_cta || '; ' || SQLERRM;
            END;
            /** Si es tarjeta Vencida. **/
         ELSIF p_cod_mod = 5 AND p_observacion NOT IN ('INC-1.2', 'MOD-1.2', 'MOD-1.9') THEN
            BEGIN
               SELECT fec_apertura INTO v_fec FROM ov_cta_vencidas WHERE nro_cuenta = p_nro_cta;
            EXCEPTION
               WHEN OTHERS THEN
                  --v_err := 'Error al buscar la fecha de apertura de la cuenta(ov_cta_vencidas-Tarjetas) ' || p_nro_cta || '; ' || sqlerrm;
                  /** Sino encuentra Busca en ta_Cta_tarjetas. **/
                  SELECT fec_apertura INTO v_fec FROM ta_cta_tarjetas WHERE nro_cuenta = p_nro_cta;
            END;
            /** Si es tarjeta Vencida. **/
         ELSIF p_cod_mod = 5 AND p_observacion IN ('MOD-1.9') THEN
            BEGIN
               SELECT fec_apertura INTO v_fec FROM ta_cta_tarjetas WHERE nro_cuenta = p_nro_cta;
            EXCEPTION
               WHEN OTHERS THEN
                  v_err := 'Error al buscar la fecha de apertura de la cuenta(ta_cta_tarjetas-Tarjetas) ' ||
                           p_nro_cta || '; ' || SQLERRM;
            END;

            /** Si es Préstamo. **/
         ELSIF p_cod_mod = 6 THEN
            BEGIN
               SELECT fec_inicio INTO v_fec FROM pr_cta_prestamos WHERE nro_cuenta = p_nro_cta;
            EXCEPTION
               WHEN OTHERS THEN
                  v_err := 'Error al buscar la fecha de apertura de la cuenta(pr_cta_prestamos) ' ||
                           p_nro_cta || '; ' || SQLERRM;
            END;
            /** Si es sobregiro. **/
         ELSIF p_cod_mod = 4 THEN
            BEGIN
               SELECT fec_apertura INTO v_fec FROM ov_cta_vencidas WHERE nro_cuenta = p_nro_cta;
            EXCEPTION
               WHEN no_data_found THEN
                  /** Buscamos en cc_cta_corrientes. **/
                  SELECT fec_apertura
                    INTO v_fec
                    FROM cc_cta_corrientes
                   WHERE nro_cuenta = p_nro_cta;

               WHEN OTHERS THEN
                  v_err := 'Error al buscar la fecha de apertura de la cuenta(ov_cta_vencidas-Sobregiro) ' ||
                           p_nro_cta || '; ' || SQLERRM;
            END;

         END IF;
         /** Obtener la Equivalencia de co_inf_monedas. **/
         BEGIN
            v_mon := NULL;
            SELECT a.cod_inf_moneda
              INTO v_mon
              FROM co_inf_monedas a
             WHERE TRIM(a.cod_moneda) = TRIM(p_cod_mon);
         EXCEPTION
            WHEN no_data_found THEN
               v_err := 'Error no existe equivalencia en CO_INF_MONEDAS Cta./Mon.:' || p_nro_cta || '/' ||
                        p_cod_mon || '; ' || SQLERRM;
         END;
         IF v_err IS NULL THEN
            p_fec_ope := v_fec;
            p_inf_mon := v_mon;
            p_error   := NULL;
         ELSE
            p_fec_ope := NULL;
            p_inf_mon := NULL;
            p_error   := v_err;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            v_err     := 'ERROR. En el proceso interno de datos con la cuenta ' || p_nro_cta || '; ' ||
                         SQLERRM;
            p_fec_ope := NULL;
            p_inf_mon := NULL;
            p_error   := v_err;
      END;
   BEGIN
      /** Busca los parámetros para el proceso. **/
      v_nro     := '1';
      v_cod_afi := v_afiliado;
      FOR i IN 1 .. 3 LOOP
         v_cod_operacion := NULL;
         v_tip_envio     := translate(i, '123', 'EMI');
         v_nro           := '3';
         v_procesar      := FALSE;
         v_buffer        := NULL;

         OPEN datos(v_tip_envio);
         FETCH datos
            INTO r_datos;
         v_nro := '4';
         IF datos%NOTFOUND THEN
            v_procesar := FALSE;
         ELSE
            v_procesar := TRUE;
         END IF;
         CLOSE datos;
         v_nro := '5';
         IF v_procesar THEN
            /** Crea el archivo para enviar a Informconf. **/
            v_nro         := '6';
            v_nom_archivo := lpad(v_cod_afi, 6, '0');
            v_nom_archivo := v_nom_archivo || to_char(nvl(p_fec_envio, c_fec_actual), 'YYMMDD') ||
                             lower(v_tip_envio) || '.cob';
            v_nro         := '7';

            v_archivo := utl_file.fopen(v_directorio, v_nom_archivo, 'W');

            /** Modificado PARA ENVIO DE MAIL. **/
            conn := it_mail.begin_mail(v_dir_cor_remitente, v_dir_cor_destinatario,
                                       'ARCHIVO DE COBRANZAS-INFORMCONF -BANCO '|| fug_obt_pardinamico('NOM_BANCO'),
                                       it_mail.multipart_mime_type);
            it_mail.attach_text(conn,
                                '--------------------------------------------------------------------' ||
                                 chr(10) ||
                                 '--Enviada de Manera Automática desde BANCO '|| fug_obt_pardinamico('NOM_BANCO')||' para INFORMCONF-' ||
                                 chr(10) ||
                                 '--------------------------------------------------------------------' ||
                                 chr(10) || '---- Datos del Envio --> Fecha : ' ||
                                 to_char(SYSDATE, 'DD/MM/YYYY') || '  ' || ' ---> Hora : ' ||
                                 to_char(SYSDATE, 'hh:mm') || ' ----' || chr(10) ||
                                 '--------------------------------------------------------------------',
                                'text/plain');

            it_mail.begin_attachment(conn, 'text/plain', FALSE, v_nom_archivo);
            FOR d IN datos(v_tip_envio) LOOP
               IF nvl(v_old_nro_cta, ' ') <> d.nro_cuenta OR nvl(v_old_nro_cuo, 0) <> d.nro_cuota THEN
                  v_nro         := '8';
                  v_mensaje     := NULL;
                  v_fec_ope     := NULL;
                  v_tip_inf_mon := NULL;
                  lp_carga_datos(d.nro_cuenta, d.cod_modulo, d.cod_moneda, d.observacion, v_fec_ope,
                                 v_tip_inf_mon, v_mensaje);
                  IF v_mensaje IS NOT NULL THEN
                     RAISE v_error;
                  END IF;
                  v_nro := '9';
                  /** Tarjetas. **/
                  IF d.cod_modulo = 5 THEN
                     /** Para tarjetas se envia en el código de operación el nro. de tarjeta. **/
                     v_cod_operacion := d.nro_tarjeta;
                     /** Préstamos. **/
                  ELSE
                     /** Para préstamos el nro. de cuenta. **/
                     v_cod_operacion := d.nro_cuenta;
                  END IF;

                  v_buffer := lpad(nvl(to_char(v_cod_afi), ' '), 6, 0) ||
                              rpad(nvl(to_char(c_fec_actual, 'YYYYMMDD'), '0'), 8, '0') ||
                              rpad(nvl(d.nro_documento, ' '), 15, ' ') ||
                              rpad(nvl(d.pri_nombre, ' '), 65, ' ') ||
                              rpad(nvl(d.seg_nombre, ' '), 15, ' ') ||
                              rpad(nvl(d.pri_apellido, ' '), 20, ' ') ||
                              rpad(nvl(d.seg_apellido, ' '), 20, ' ') ||
                              rpad(nvl(d.ape_casada, ' '), 20, ' ') ||
                              rpad(nvl(d.dir_particular, ' '), 65, ' ') ||
                              rpad(nvl(d.dir_laboral, ' '), 65, ' ') ||
                              rpad(nvl(d.dir_lab_alternativo, ' '), 65, ' ') ||
                              rpad(nvl(d.tel_particular, ' '), 20, ' ') ||
                              rpad(nvl(d.tel_laboral, ' '), 20, ' ') ||
                              rpad(nvl(d.tel_lab_alternativo, ' '), 20, ' ') ||
                              rpad(nvl(v_cod_operacion, ' '), 25, ' ') ||
                              rpad(nvl(to_char(v_fec_ope, 'YYYYMMDD'), '0'), 8, '0') ||
                              lpad(nvl(to_char(d.can_cuotas), '0'), 3, '0') ||
                              lpad(nvl(d.tip_inf_operacion, ' '), 1, ' ') ||
                              lpad(nvl(to_char(d.pri_cuo_atrasada), '0'), 3, '0') ||
                              lpad(nvl(to_char(d.can_cuo_atrasada), '0'), 3, '0') ||
                              lpad(nvl(REPLACE(translate(to_char(d.mto_cuota,
                                                                 '999999999999999999D99'), ',.', '  '),
                                               ' ', NULL), '0'), 20, '0') ||
                              rpad(nvl(to_char(d.fec_vencimiento, 'YYYYMMDD'), '0'), 8, '0') ||
                              rpad(nvl(to_char(d.fec_ult_pago, 'YYYYMMDD'), '0'), 8, '0') ||
                              rpad(nvl(d.tip_inf_garantia, '0'), 1, ' ') ||
                              rpad(nvl(v_tip_inf_mon, ' '), 1, ' ') ||
                              lpad(nvl(REPLACE(translate(to_char(d.mto_deuda,
                                                                 '999999999999999999D99'), ',.', '  '),
                                               ' ', NULL), '0'), 20, '0') ||
                              rpad(nvl(to_char(d.fec_final, 'YYYYMMDD'), '0'), 8, '0') ||
                              rpad(nvl(d.tip_inf_cobro, ' '), 1, ' ') ||
                              lpad(nvl(REPLACE(translate(to_char(d.mto_cobrado,
                                                                 '999999999999999999D99'), ',.', '  '),
                                               ' ', NULL), '0'), 20, '0') ||
                              rpad(nvl(to_char(d.fec_cobro, 'YYYYMMDD'), '0'), 8, '0') ||
                             /** Modificado para tipo de Pago. **/
                              rpad(nvl(d.tip_inf_actualizacion, ' '), 1, ' ') ||
                              rpad(nvl(d.inf_periodicidad, ' '), 1, ' ') ||
                              rpad(nvl(v_tip_envio, ' '), 1, ' ') ||
                              rpad(nvl(d.nro_tarjeta, ' '), 30, ' ');
                  utl_file.put_line(v_archivo, v_buffer);
                  v_buffer := v_buffer || chr(10);

                  --it_mail.write_text(conn,v_buffer);
                  it_mail.write_mb_text(conn, v_buffer);

               END IF;
               v_nro         := '12';
               v_old_nro_cta := d.nro_cuenta;
               v_old_nro_cuo := d.nro_cuota;
            END LOOP;
            utl_file.fclose(v_archivo);
            /** Para envio de mail. **/
            it_mail.end_mail(conn);
            v_nro := '14';
         END IF;
      END LOOP;
   EXCEPTION
      WHEN v_error THEN
         raise_application_error(-20852,
                                 'ITC-GEN.ARCH.:' || v_nro || ': (' || to_char(v_regs) || ') ' ||
                                  v_mensaje);
      WHEN OTHERS THEN
         raise_application_error(-20853,
                                 'ITC-GEN.ARCH.:' || v_nro || ': (' || to_char(v_regs) || ') ' ||
                                  'Error en el proceso de control de actividades de cobranzas ' ||
                                  SQLERRM);
   END pr_gen_inf_archivo;

   /** Informconf- Inserta en CO_INF_COB_DIARIOS. **/
   PROCEDURE pr_gen_inf_linea
   (
      p_linea     co_inf_cob_personas%ROWTYPE,
      p_tip_envio VARCHAR2
   ) IS
   BEGIN
      DECLARE
         /** Fecha actual del Módulo de Cobranzas. **/
         c_fec_actual CONSTANT DATE := fuo_fec_strategy; -- Fecha del dia anterior del módulo de Cobranzas
      BEGIN
         INSERT INTO co_inf_cob_diarios
            (fec_envio, cod_usu_gestion, cod_persona, nro_cuenta, nro_cuota, tip_envio, cod_modulo,
             cod_modalidad, cod_moneda, nro_documento, dir_particular, dir_laboral,
             dir_lab_alternativo, tel_particular, tel_laboral, tel_lab_alternativo, can_cuotas,
             tip_inf_operacion, pri_cuo_atrasada, can_cuo_atrasada, mto_cuota, fec_vencimiento,
             fec_ult_pago, tip_inf_garantia, mto_deuda, fec_final, tip_inf_cobro, mto_cobrado,
             fec_cobro, tip_inf_actualizacion, inf_periodicidad, nro_tarjeta, dia_atraso,
             observacion, nro_cta_nueva, cod_ori_modulo, cod_ori_modalidad)
         VALUES
            (c_fec_actual, p_linea.cod_usu_gestion, p_linea.cod_persona, p_linea.nro_cuenta,
             p_linea.nro_cuota, p_tip_envio, p_linea.cod_modulo, p_linea.cod_modalidad,
             p_linea.cod_moneda, p_linea.nro_documento, p_linea.dir_particular, p_linea.dir_laboral,
             p_linea.dir_lab_alternativo, p_linea.tel_particular, p_linea.tel_laboral,
             p_linea.tel_lab_alternativo, p_linea.can_cuotas, p_linea.tip_inf_operacion,
             p_linea.pri_cuo_atrasada, p_linea.can_cuo_atrasada, p_linea.mto_cuota,
             p_linea.fec_vencimiento, p_linea.fec_ult_pago, p_linea.tip_inf_garantia,
             p_linea.mto_deuda, p_linea.fec_final, p_linea.tip_inf_cobro, p_linea.mto_cobrado,
             p_linea.fec_cobro, p_linea.tip_inf_actualizacion, p_linea.inf_periodicidad,
             p_linea.nro_tarjeta, p_linea.dia_atraso, p_linea.observacion, p_linea.nro_cta_nueva,
             p_linea.cod_ori_modulo, p_linea.cod_ori_modalidad);
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20471,
                                    'No se pudo guardar el historial de la cuenta ' ||
                                     p_linea.nro_cuenta || '; ' || SQLERRM);
      END;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20472,
                                    'Error al procesar el historial de la cuenta ' ||
                                     p_linea.nro_cuenta || '; ' || SQLERRM);
         END IF;
   END pr_gen_inf_linea;

   /** Obtiene la Cuenta Cabecera (en mora) del Cliente. **/
   FUNCTION fu_obt_cta_cabecera(p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
      v_cod_banca    NUMBER(3);
      v_nro_cuenta   VARCHAR2(15);
      v_fecha        DATE := pag_cal.fu_obt_fec_actual(1);
      v_fec_anterior DATE;
      ----
      CURSOR cuentas_bp IS
      /** Préstamos.**/
         SELECT p.nro_cuenta, p.dia_atraso dia_atraso, p.cod_modulo, p.cod_modalidad
           FROM pr_cta_prestamos p, ge_cta_clientes cc
          WHERE cc.cod_persona = p_cod_persona
            AND p.nro_cuenta = cc.nro_cuenta
            AND cc.relacion = 'P'
            AND nvl(p.dia_atraso, 0) > 0
            AND p.estado NOT IN ('N', 'I')
            AND (p.cod_modulo, p.cod_modalidad) IN
                (SELECT d.cod_modulo, d.cod_modalidad
                   FROM ge_par_dinamicos d
                  WHERE d.parametro = 'MOD_COBRANZAS'
                    AND nvl(d.val_parametro, 'N') = 'S'
                    AND d.cod_modulo = 6
                    AND d.cod_modulo = p.cod_modulo
                    AND d.cod_modalidad = p.cod_modalidad)
            AND NOT EXISTS (SELECT 1
                   FROM co_inf_cob_personas x
                  WHERE x.cod_persona = cc.cod_persona
                    AND x.nro_cuenta = p.nro_cuenta)
         --AND p.cod_modalidad NOT IN (60, 650, 651, 652, 660) /** Modalidades no gestionables. **/
         /* and NOT EXISTS( select 1
          from ge_par_dinamicos x
         where x.parametro like 'COD_CAN_%' --Canales no Gestionables--
           and x.parametro not like 'COD_CAN_AGE_%'
           and x.val_parametro = to_char( p.cod_canal ) )*/
         /*AND EXISTS (SELECT 1
          FROM pr_cuotas cu
         WHERE cu.nro_cuenta = p.nro_cuenta
           AND cu.nro_cuota > 0
           AND cu.estado <> 'N'
           AND cu.fec_vencimiento < v_fecha)*/
         UNION ALL
         /** Tarjetas.**/
         SELECT t.nro_cuenta, t.dia_mora, t.cod_modulo, t.cod_modalidad
           FROM ge_cta_clientes c, ta_cta_tarjetas t
          WHERE c.cod_persona = p_cod_persona
            AND t.nro_cuenta = c.nro_cuenta
            AND c.relacion = 'P'
            AND nvl(t.dia_mora, 0) > 0
            AND t.estado <> 'C'
            AND (t.cod_modulo, t.cod_modalidad) IN
                (SELECT d.cod_modulo, d.cod_modalidad
                   FROM ge_par_dinamicos d
                  WHERE d.parametro = 'MOD_COBRANZAS'
                    AND nvl(d.val_parametro, 'N') = 'S'
                    AND d.cod_modulo = 5
                    AND d.cod_modulo = t.cod_modulo
                    AND d.cod_modalidad = t.cod_modalidad)
               --AND t.cod_modalidad NOT IN (50, 51)
            AND NOT EXISTS (SELECT 1
                   FROM co_inf_cob_personas x
                  WHERE x.cod_persona = c.cod_persona
                    AND x.nro_cuenta = t.nro_cuenta
                    AND x.nro_cuota = 0)
         /*AND NOT EXISTS (SELECT 1
          FROM ta_cobros co
         WHERE co.nro_cuenta = t.nro_cuenta
           AND co.fec_proceso >= v_fec_anterior
              --and co.est_envio = 'P'
           AND co.monto >= t.mto_mora
           AND co.fec_valor > nvl(t.fec_ult_pago, '01/01/1900'))*/
         UNION ALL
         /** Operaciones Vencidas.**/
         SELECT m.nro_cta_origen nro_cuenta,
                nvl(m.dia_atraso, 0) dia_atraso,
                m.cod_modulo,
                m.cod_modalidad
           FROM ov_cta_vencidas m, ge_cta_clientes t
          WHERE t.cod_persona = p_cod_persona
            AND m.nro_cta_origen = t.nro_cuenta
            AND nvl(t.relacion, 'X') = 'P'
            AND nvl(m.dia_atraso, 0) > 0
            AND m.estado <> 'C'
            AND (m.cod_modulo, m.cod_modalidad) IN
                (SELECT d.cod_modulo, d.cod_modalidad
                   FROM ge_par_dinamicos d
                  WHERE d.parametro = 'MOD_COBRANZAS'
                    AND nvl(d.val_parametro, 'N') = 'S'
                    AND d.cod_modulo = 15
                    AND d.cod_modulo = m.cod_modulo
                    AND d.cod_modalidad = m.cod_modalidad)
            AND NOT EXISTS (SELECT 1
                   FROM co_inf_cob_personas s
                  WHERE s.cod_persona = t.cod_persona
                    AND s.nro_cuenta = m.nro_cta_origen
                    AND s.nro_cuota = 0)
         UNION ALL
         /** Cuentas Corrientes.**/
         SELECT x.nro_cuenta, r.can_dias, x.cod_modulo, x.cod_modalidad
           FROM cc_cta_corrientes x, ge_cta_clientes t, cc_sobregiros_res r
          WHERE t.cod_persona = p_cod_persona
            AND x.nro_cuenta = t.nro_cuenta
            AND x.nro_cuenta = r.nro_cuenta(+)
            AND nvl(t.relacion, 'X') = 'P'
            AND nvl(r.can_dias, 0) > 0
            AND x.estado = 'N'
            AND (x.cod_modulo, x.cod_modalidad) IN
                (SELECT d.cod_modulo, d.cod_modalidad
                   FROM ge_par_dinamicos d
                  WHERE d.parametro = 'MOD_COBRANZAS'
                    AND nvl(d.val_parametro, 'N') = 'S'
                    AND d.cod_modulo = 4
                    AND d.cod_modulo = x.cod_modulo
                    AND d.cod_modalidad = x.cod_modalidad)
            AND NOT EXISTS (SELECT 1
                   FROM co_inf_cob_personas s
                  WHERE s.cod_persona = t.cod_persona
                    AND s.nro_cuenta = x.nro_cuenta
                    AND s.nro_cuota = 0)
          ORDER BY dia_atraso DESC, cod_modulo DESC, cod_modalidad DESC, nro_cuenta;

      /*CURSOR cuentas_bc IS
      SELECT t.nro_cuenta, t.dia_mora dia_atraso, t.cod_modulo, t.cod_modalidad
        FROM ge_cta_clientes c, ta_cta_tarjetas t
       WHERE c.cod_persona = p_cod_persona
         AND t.nro_cuenta = c.nro_cuenta
         AND c.relacion = 'P'
         AND nvl(t.dia_mora, 0) > 0
         AND t.estado <> 'C'
         AND (t.cod_modulo, t.cod_modalidad) IN
             (SELECT d.cod_modulo, d.cod_modalidad
                FROM ge_par_dinamicos d
               WHERE d.parametro = 'MOD_COBRANZAS'
                 AND nvl(d.val_parametro, 'N') = 'S'
                 AND d.cod_modulo = 5
                 AND d.cod_modulo = t.cod_modulo
                 AND d.cod_modalidad = t.cod_modalidad)
         --AND t.cod_modalidad NOT IN (50, 51)
         AND NOT EXISTS (SELECT 1
                FROM ta_cobros co
               WHERE co.nro_cuenta = t.nro_cuenta
                 AND co.fec_proceso >= v_fec_anterior
                    --and co.est_envio = 'P'
                 AND co.monto >= t.mto_mora
                 AND co.fec_valor > nvl(t.fec_ult_pago, '01/01/1900'))
       ORDER BY dia_atraso DESC, cod_modulo DESC, cod_modalidad DESC, nro_cuenta;*/

   BEGIN
      /** Agregado por cobros on line ya enviados pero que bancard procesa al dia siguiente cuando se envia de tarde. **/
      IF ltrim(rtrim(upper(to_char(v_fecha, 'DAY')))) IN ('MONDAY', 'LUNES') THEN
         /** Si es lunes restar 2 dias habiles porque sabado no se corre el proceso. **/
         v_fec_anterior := pag_cal.fu_obt_fec_ant_hab(v_fecha, 1, 3);
      ELSE
         v_fec_anterior := pag_cal.fu_obt_fec_ant_hab(v_fecha, 1, 1);
      END IF;
      --  v_fec_anterior := pag_cal.FU_OBT_FEC_ANT_HAB(v_fecha,1);
      SELECT cod_banca INTO v_cod_banca FROM ge_clientes x WHERE x.cod_persona = p_cod_persona;

      --IF v_cod_banca IN (2) THEN
      FOR cue IN cuentas_bp LOOP
         v_nro_cuenta := cue.nro_cuenta;
         EXIT;
      END LOOP;
      /*ELSIF v_cod_banca <> 5 THEN
         \** Sólo verificar mora de tarjetas para bca <> recuperaciones (esa banca no se asigna). **\
         FOR cue IN cuentas_bc LOOP
            v_nro_cuenta := cue.nro_cuenta;
            EXIT;
         END LOOP;
      END IF;*/

      IF v_nro_cuenta IS NOT NULL THEN
         RETURN v_nro_cuenta;
      ELSE
         RETURN 0;
      END IF;
   END fu_obt_cta_cabecera;
   /** Determina si un cliente puede ser agendado para cobranzas Banca Personal (siempre que entre en mora).
   TIPO R devuelve S/N segun impedimentos del cliente.
   TIPO D devuelve el detalle de los impedimentos (para saber porqué no cumple las condiciones). **/
   FUNCTION fu_pue_age_cobranzas
   (
      p_cod_persona IN VARCHAR2,
      p_tipo        IN VARCHAR2 DEFAULT 'R'
   ) RETURN VARCHAR2 IS
      result VARCHAR2(2000) := 'N';
      --v_cod_banca        ge_clientes.cod_banca%TYPE;
      v_can_impedimentos NUMBER(4) := 0;
      v_can_tarjetas     NUMBER(4) := 0;
      v_cli_especial     VARCHAR2(1) := 'N';
      v_tip_gru_cobranza ge_clientes.tip_gru_cobranza%TYPE;
      v_funcionario      NUMBER(3) := 0;
      v_cod_usu_rrhh     ge_clientes.cod_usu_oficial%TYPE := fug_obt_pardinamico('OFICIAL_RRHH',
                                                                                 NULL, NULL, NULL,
                                                                                 NULL);
      v_det_impedimentos VARCHAR2(2000) := NULL;
      v_inhibiciones     NUMBER(4) := 0;
   BEGIN
      /** Controlar banca, tipo de agrupación para cobranza y que no sea cliente VIP. **/
      SELECT nvl(x.cli_especial, 'N'), nvl(x.tip_gru_cobranza, 0) --, nvl(x.cod_banca, 2)
        INTO v_cli_especial, v_tip_gru_cobranza --, v_cod_banca
        FROM ge_clientes x
       WHERE x.cod_persona = p_cod_persona;
      IF v_cli_especial = 'S' THEN
         v_can_impedimentos := v_can_impedimentos + 1;
         IF p_tipo = 'D' THEN
            v_det_impedimentos := v_det_impedimentos || '=>Tiene marca de Cliente especial <=';
         END IF;
      END IF;
      /*IF (v_can_impedimentos = 0 AND p_tipo = 'R') OR p_tipo = 'D' THEN
         \** PPALELLA: Se asignan clientes de banca minoristas y banca personas. **\
         IF v_cod_banca NOT IN (2) THEN
            SELECT COUNT(*)
              INTO v_can_tarjetas
              FROM ta_cta_tarjetas t, ge_cta_clientes c
             WHERE t.nro_cuenta = c.nro_cuenta
               AND c.cod_persona = p_cod_persona
               AND c.relacion = 'P'
               AND t.estado <> 'C';
            IF v_can_tarjetas = 0 THEN
               \** BCA corporativo o pymes sin tarjetas. **\
               v_can_impedimentos := v_can_impedimentos + 1;
            END IF;
            IF v_cod_banca = 5 AND v_can_tarjetas > 0 THEN
               \** No asignar BCA recuperaciones aunque tenga TC . **\
               v_can_impedimentos := v_can_impedimentos + 1;
            END IF;
            IF p_tipo = 'D' THEN
               v_det_impedimentos := v_det_impedimentos ||
                                     '=>Cliente no es de Banca Minorista/Personas<=';
            END IF;
         END IF;
      END IF;*/
      /** Controlar que no sea funcionario. **/
      IF (v_can_impedimentos = 0 AND p_tipo = 'R') OR p_tipo = 'D' THEN
         SELECT COUNT(*) INTO v_funcionario FROM ba_usuarios x WHERE x.cod_persona = p_cod_persona;
         IF v_funcionario = 0 THEN
            SELECT COUNT(*)
              INTO v_funcionario
              FROM ge_clientes x
             WHERE x.cod_persona = p_cod_persona
               AND x.cod_usu_oficial = v_cod_usu_rrhh;
         END IF;
         IF v_funcionario > 0 THEN
            v_can_impedimentos := v_can_impedimentos + 1;
            IF p_tipo = 'D' THEN
               v_det_impedimentos := v_det_impedimentos || '=>Cliente es Funcionario<=';
            END IF;
         END IF;
      END IF;
      /** Controlar que no tenga inhibición por Fallecimiento. **/
      IF (v_can_impedimentos = 0 AND p_tipo = 'R') OR p_tipo = 'D' THEN
         SELECT COUNT(*)
           INTO v_inhibiciones
           FROM ge_per_inhibidas i
          WHERE i.cod_persona = p_cod_persona
            AND i.estado = 'I'
            AND i.cod_causa = 281;
         IF v_inhibiciones > 0 THEN
            v_can_impedimentos := v_can_impedimentos + 1;
            IF p_tipo = 'D' THEN
               v_det_impedimentos := v_det_impedimentos || '=>Cliente Fallecido<=';
            END IF;
         END IF;
      END IF;
      IF v_can_impedimentos = 0 AND p_tipo = 'R' THEN
         result := 'S';
      ELSIF v_can_impedimentos = 0 AND p_tipo = 'D' THEN
         result := 'Cliente no posee impedimentos';
      ELSIF v_can_impedimentos >= 1 AND p_tipo = 'R' THEN
         result := 'N';
      ELSIF v_can_impedimentos >= 1 AND p_tipo = 'D' THEN
         result := v_det_impedimentos;
      END IF;
      RETURN result;
   END fu_pue_age_cobranzas;

   -- Obtiene el tipo de Garantía.
   FUNCTION fu_obt_garantia
      (
         p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
         p_cod_modulo  ge_cuentas.cod_modulo%TYPE,
         p_observacion VARCHAR2
      ) RETURN NUMBER IS
            v_cod NUMBER(3);
    BEGIN
       IF p_cod_modulo = 5 AND p_observacion IN ('INC-1.2', 'MOD-1.2') THEN
          /** Si es tarjeta Normal. **/
          BEGIN
             SELECT cod_garantia
               INTO v_cod
               FROM ta_cta_garantias
              WHERE nro_cuenta = p_nro_cuenta
                AND rownum = 1;
          EXCEPTION
             WHEN OTHERS THEN
                v_cod := NULL;
          END;
       ELSIF p_cod_modulo = 5 AND p_observacion NOT IN ('INC-1.2', 'MOD-1.2') THEN
          /** Si es tarjeta Vencida. **/
          BEGIN
             SELECT c.cod_garantia
               INTO v_cod
               FROM ov_cta_vencidas a, ta_cta_tarjetas b, ta_cta_garantias c
              WHERE a.nro_cta_origen = b.nro_cuenta
                AND b.nro_cuenta = c.nro_cuenta
                AND a.nro_cuenta = p_nro_cuenta
                AND rownum = 1;
          EXCEPTION
             WHEN OTHERS THEN
                v_cod := NULL;
          END;
       ELSIF p_cod_modulo = 6 THEN
          /** Si es préstamo. **/
          BEGIN
             SELECT cod_garantia
               INTO v_cod
               FROM pr_cta_garantias
              WHERE nro_cuenta = p_nro_cuenta
                AND rownum = 1;
          EXCEPTION
             WHEN OTHERS THEN
                v_cod := NULL;
          END;
          /** Se busca la garantia en sobregiros o cta_cte. **/
       ELSIF p_cod_modulo = 4 THEN
          /** Si es sobregiro o cta_cte se asume a sola firma. **/
          v_cod := 1;

       END IF;
       RETURN v_cod;
   END fu_obt_garantia;

   /** Inserta el log en la tabla de logs de cobranzas. **/
   PROCEDURE pr_ins_log
   (
      p_log   IN co_log_asignaciones%ROWTYPE,
      p_error IN BOOLEAN DEFAULT TRUE
   ) IS
      v_log co_log_asignaciones%ROWTYPE;
   BEGIN
      v_log := p_log;
      IF p_error THEN
         v_log.nro_error := SQLCODE;
         v_log.msg_error := SQLERRM;
      END IF;
      INSERT INTO co_log_asignaciones
         (nom_proceso, hor_inicio, hor_fin, nro_registro, nro_error, msg_error, comentario)
      VALUES
         (v_log.nom_proceso, v_log.hor_inicio, SYSDATE, v_log.nro_registro, v_log.nro_error,
          v_log.msg_error, v_log.comentario);
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

   /** Inserta el log en la tabla de logs de cobranzas. **/
   PROCEDURE pr_log
   (
      p_mensaje co_log_asignaciones.comentario%TYPE,
      p_error   BOOLEAN DEFAULT TRUE
   ) IS
      r_log co_log_asignaciones%ROWTYPE;
   BEGIN
      r_log.hor_fin    := SYSDATE;
      r_log.comentario := p_mensaje;
      /** Agregado para hacer Test. **/
      /*
        IF p_error THEN
          dbms_output.put_line( r_log.nro_reg );
          dbms_output.put_line( r_log.comentario );
          dbms_output.put_line( substr( sqlerrm, 1, 250 ) );
        ELSE
          dbms_output.put_line( substr( r_log.comentario, 1, 250 ) );
        END IF;
      */
      pr_ins_log(r_log, p_error);
   EXCEPTION
      WHEN OTHERS THEN
         pr_ins_log(r_log, p_error);
         NULL;
   END pr_log;

   /** Obtiene el tramo nuevo que le correponde al cliente. **/
   FUNCTION fu_obt_tramo(
                         /*p_tip_gru_cobranza IN VARCHAR2,*/p_cta_cabecera IN VARCHAR2) RETURN NUMBER IS
      v_dias      NUMBER(18) := 0;
      v_cod_tramo NUMBER(3);
   BEGIN
      SELECT t.dia_atraso INTO v_dias FROM ge_cuentas t WHERE t.nro_cuenta = p_cta_cabecera;
      IF v_dias > 0 THEN
         BEGIN
            SELECT t.cod_tramo
              INTO v_cod_tramo
              FROM co_trm_asignaciones_det t
             WHERE t.tip_tramo = 'O' --p_tip_gru_cobranza
               AND v_dias BETWEEN t.dia_inicial AND t.dia_final;
         EXCEPTION
            /*WHEN no_data_found THEN
            BEGIN
               SELECT t.cod_tramo
                 INTO v_cod_tramo
                 FROM co_trm_asignaciones_det t
                WHERE t.tip_tramo = 'O'
                  AND v_dias BETWEEN t.dia_inicial AND t.dia_final;
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;*/
            WHEN OTHERS THEN
               NULL;
         END;
      END IF;
      IF v_cod_tramo IS NOT NULL THEN
         RETURN v_cod_tramo;
      ELSE
         RETURN 0;
      END IF;
   END fu_obt_tramo;

   /** Obtiene el tipo de gestor que corresponde al tramo. **/
   FUNCTION fu_obt_tip_gestor(p_cod_tramo IN NUMBER) RETURN VARCHAR2 IS
      v_tip_gestor VARCHAR2(1);
   BEGIN
      SELECT t.tip_gestor /*DISTINCT CASE
                                                                                                                                                       WHEN t.tip_gestor IN ('M', 'G') THEN
                                                                                                                                                        'G'
                                                                                                                                                       ELSE
                                                                                                                                                        t.tip_gestor
                                                                                                                                                    END tip_gestor*/
        INTO v_tip_gestor
        FROM co_trm_grupos t
       WHERE t.cod_tramo = p_cod_tramo;

      RETURN(v_tip_gestor);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN(NULL);
   END fu_obt_tip_gestor;

   /** Devuelve los datos si el cliente tiene tramo actual vigente. **/
   PROCEDURE pr_ver_tra_actual
   (
      p_cod_persona        IN VARCHAR2,
      p_tramo              OUT NUMBER,
      p_cod_agenda         OUT NUMBER,
      p_fec_ini_asignacion OUT DATE,
      p_cta_cabecera       OUT VARCHAR2
   ) IS

   BEGIN
      /** Verifica si el cliente tiene tramo de mora actual activo. **/
      SELECT co.cod_tramo, co.cod_agenda, co.fec_ini_asignacion, cd.nro_cuenta
        INTO p_tramo, p_cod_agenda, p_fec_ini_asignacion, p_cta_cabecera
        FROM co_asignaciones co, co_asignaciones_det cd
       WHERE co.cod_persona = p_cod_persona
         AND co.fec_fin_asignacion IS NULL
         AND co.cod_persona = cd.cod_persona
         AND co.fec_ini_asignacion = cd.fec_ini_asignacion
         AND cd.pro_cabecera = 'S';
   EXCEPTION
      WHEN no_data_found THEN
         p_tramo              := NULL;
         p_cod_agenda         := NULL;
         p_fec_ini_asignacion := NULL;
         p_cta_cabecera       := NULL;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'PRO_VER_TRA_ACTUAL ' || SQLERRM);
   END pr_ver_tra_actual;
   /** Proceso de Generación de asignaciones de cobranzas Bca Personal. **/
   PROCEDURE pr_gen_asignaciones IS
      v_lugar              VARCHAR2(500) := NULL;
      v_fecha              DATE := pag_cal.fu_obt_fec_actual(21);
      v_fec_anterior       DATE;
      v_fec_cobros         DATE;
      v_fec_control        DATE;
      v_cod_tramo          NUMBER(4);
      v_tip_gestor         VARCHAR2(1);
      v_tra_actual         NUMBER(4) := NULL;
      v_cod_agenda         cr_agendas.cod_agenda%TYPE := NULL;
      v_motivo             cr_cta_tramos.mot_cancelacion%TYPE;
      v_cta_cabecera       ge_cuentas.nro_cuenta%TYPE;
      v_cta_cab_actual     ge_cuentas.nro_cuenta%TYPE;
      v_fec_ini_asignacion DATE;
      v_mto_cobrado        NUMBER(18, 2) := 0;
      v_continuar          VARCHAR2(1) := 'N'; /**DEBE SER N -- CAMBIAR A 'S' para que ejecute sin procesar cobros. **/
      v_cobro              NUMBER(1) := 0;
      v_realizado          NUMBER(5) := 0;
      r_log                co_log_asignaciones%ROWTYPE;
      v_reg                NUMBER;
      ---
      /** Clientes en mora potenciales a asignar a un gestor. **/
      CURSOR c_clientes IS
         SELECT c.cod_persona,
                nvl(c.tip_gru_cobranza, 0) tip_gru_cobranza,
                c.cod_banca,
                c.cod_oficina,
                c.cod_usu_oficial
           FROM ge_clientes c
          WHERE pao_cob.fu_pue_age_cobranzas(c.cod_persona, 'R') = 'S'
            AND pao_cob.fu_obt_cta_cabecera(c.cod_persona) > 0
            AND c.cod_persona NOT IN (1);
      /** Tramo activo pero cliente ya no cumple con las condiciones para seguir asignado. **/
      CURSOR c_tramos IS
         SELECT t.cod_tramo,
                t.fec_ini_asignacion,
                nvl(x.tip_gru_cobranza, 0) tip_gru_cobranza,
                t.cod_persona,
                d.nro_cuenta cta_cabecera
           FROM co_asignaciones t, co_asignaciones_det d, ge_clientes x
          WHERE x.cod_persona = t.cod_persona
            AND t.fec_fin_asignacion IS NULL
            AND d.cod_persona = t.cod_persona
            AND d.fec_ini_asignacion = t.fec_ini_asignacion
            AND d.pro_cabecera = 'S'
          ORDER BY t.cod_tramo, t.fec_ini_asignacion, x.tip_gru_cobranza, t.cod_persona;
      /*
            select t.cod_persona, t.cod_tramo, t.fec_ini_asignacion, 'O' tip_baja
                 from co_asignaciones_cab t
                where t.fec_fin_asignacion IS NULL
                  and pao_cob.fu_pue_age_cobranzas( t.cod_persona, 'R' ) = 'N'
             UNION ALL
               select t.cod_persona, t.cod_tramo, t.fec_ini_asignacion, 'O' tip_baja
                 from co_asignaciones_cab t, ge_clientes x
                where x.cod_persona = t.cod_persona
                  and t.fec_fin_asignacion IS NULL
                  --TIENE CUENTA CABECERA PERO NO TRAMO --CLIENTES BC o priv CON TC CON MENOS DE 10 DIAS DE MORA
                  and pao_cob.fu_pue_age_cobranzas( t.cod_persona, 'R' ) = 'S'
                  and nvl( pao_cob.fu_obt_tramo( x.tip_gru_cobranza, pao_cob.fu_obt_cta_cabecera( t.cod_persona ) ), 0 )= 0;
        CURSOR c_tramos1
            IS select t.cod_persona, t.cod_tramo, t.fec_ini_asignacion, d.nro_cuenta cta_cabecera,
                      x.tip_gru_cobranza
                 from co_asignaciones_cab t, co_asignaciones_det d, ge_clientes x
                where t.fec_fin_asignacion IS NULL
                  and pao_cob.fu_pue_age_cobranzas( t.cod_persona, 'R' ) = 'S'
                  and d.cod_persona = t.cod_persona
                  and d.fec_ini_asignacion = t.fec_ini_asignacion
                  and d.pro_cabecera = 'S'
      --            and T.cod_persona IN (114253,189772,94719)
                  and x.cod_persona = t.cod_persona;
      */
      CURSOR cobros IS
         SELECT t.cod_persona,
                t.fec_ini_asignacion,
                t.cod_tramo,
                t.cod_agenda,
                d.nro_cuenta,
                d.nro_cuota,
                d.pro_cabecera,
                d.mto_atraso,
                d.mto_pagado,
                cob.fec_cobro,
                cob.mto_cobrado
           FROM co_asignaciones t,
                co_asignaciones_det d,
                (SELECT co.nro_cuenta,
                        co.nro_cuota,
                        MAX(co.fecha) fec_cobro,
                        SUM(nvl(co.mto_capital, 0) + nvl(co.mto_interes, 0) +
                            nvl(co.mto_int_documentado, 0)) mto_cobrado
                   FROM pr_cobros co
                  WHERE co.fecha >= v_fec_cobros
                    AND co.fecha < v_fecha
                  GROUP BY co.nro_cuenta, co.nro_cuota) cob
          WHERE t.fec_fin_asignacion IS NULL
            AND d.cod_persona = t.cod_persona
            AND d.fec_ini_asignacion = t.fec_ini_asignacion
            AND cob.nro_cuenta = d.nro_cuenta
            AND cob.nro_cuota = d.nro_cuota
         --and T.cod_persona IN (114253,189772,94719)
         UNION ALL
         SELECT t.cod_persona,
                t.fec_ini_asignacion,
                t.cod_tramo,
                t.cod_agenda,
                d.nro_cuenta,
                d.nro_cuota,
                d.pro_cabecera,
                d.mto_atraso,
                d.mto_pagado,
                cob.fec_cobro,
                cob.mto_cobrado
           FROM co_asignaciones t,
                co_asignaciones_det d,
                (SELECT co.nro_cuenta,
                        MAX(co.fec_proceso) fec_cobro,
                        SUM(nvl(co.monto, 0)) mto_cobrado
                   FROM ta_cobros co
                  WHERE co.fec_proceso >= v_fec_cobros
                    AND co.fec_proceso < v_fecha
                  GROUP BY co.nro_cuenta) cob
          WHERE t.fec_fin_asignacion IS NULL
            AND d.cod_persona = t.cod_persona
            AND d.fec_ini_asignacion = t.fec_ini_asignacion
            AND cob.nro_cuenta = d.nro_cuenta
         --and T.cod_persona IN (114253,189772,94719)
         ;
      /** Procedimiento que actualiza a Cancelado el Tramo. **/
      PROCEDURE lp_can_tramo
      (
         p_cod_persona        IN VARCHAR2,
         p_fec_ini_asignacion IN DATE,
         p_tra_actual         IN NUMBER,
         p_tip_baja           IN VARCHAR2
      ) IS
      BEGIN
         UPDATE co_asignaciones x
            SET x.fec_fin_asignacion = v_fecha,
                x.tip_baja           = p_tip_baja
          WHERE x.cod_persona = p_cod_persona
            AND x.fec_ini_asignacion = p_fec_ini_asignacion
            AND x.cod_tramo = p_tra_actual
            AND x.fec_fin_asignacion IS NULL;
      END;
      /** Procedimiento que actualiza a Cancelado la Agenda. **/
      PROCEDURE lp_can_agenda
      (
         p_cod_agenda IN NUMBER,
         p_motivo     IN VARCHAR2
      ) IS
         v_temp VARCHAR2(1000);
         v_desc VARCHAR2(100);
      BEGIN
         BEGIN
            SELECT e.descripcion
              INTO v_desc
              FROM cr_agendas a, cr_age_est_actividades e
             WHERE a.cod_agenda = p_cod_agenda
               AND a.cod_actividad = e.cod_actividad
               AND a.cod_estado = e.cod_estado;
         EXCEPTION
            WHEN OTHERS THEN
               v_desc := 'CANCELADO';
         END;
         v_temp := '*' || USER || '-' || to_char(v_fecha, 'DD/MM/YY') || ' ' ||
                   to_char(SYSDATE, 'HH24:MI') || '-' || v_desc || '=> ';
         UPDATE cr_agendas a
            SET a.cod_estado    = 3, --cancelado
                a.det_respuesta = substr(v_temp ||
                                         TRIM('*** ACTIVIDAD CANCELADA POR EL SISTEMA ***') ||
                                         chr(10) || p_motivo || chr(10) || a.det_respuesta, 1, 3000)
          WHERE a.cod_agenda = p_cod_agenda
         /*and a.nro_referencia like 'COBRANZA%'*/
         ;
      END;
      /** Procedimiento para inserción de Tramos. **/
      PROCEDURE lp_ins_tramo
      (
         p_cod_persona     IN VARCHAR2,
         p_cod_banca       IN NUMBER,
         p_cod_tramo       IN NUMBER,
         p_tip_gestor      IN VARCHAR2,
         p_tip_segmento    IN VARCHAR2,
         p_cod_oficina     IN NUMBER,
         p_cod_usu_oficial IN VARCHAR2
      ) IS
         v_cabecera NUMBER(1);
         CURSOR detalle_bp IS
         /** Préstamos.**/
            SELECT cc.cod_persona,
                   p.cod_modulo,
                   p.cod_modalidad,
                   p.cod_moneda,
                   p.cod_canal,
                   p.nro_cuenta,
                   p.dia_atraso dia_atraso_cta,
                   cu.nro_cuota,
                   v_fecha - cu.fec_vencimiento dia_atraso_cuota,
                   cu.fec_vencimiento fec_vto_cuota,
                   nvl(cu.sal_capital, 0) + nvl(cu.sal_interes, 0) + nvl(cu.sal_int_documentado, 0) mto_mora_cuota
              FROM pr_cta_prestamos p, ge_cta_clientes cc, pr_cuotas cu
             WHERE cc.cod_persona = p_cod_persona
               AND p.nro_cuenta = cu.nro_cuenta
               AND cu.nro_cuota > 0
               AND cu.estado <> 'N'
               AND cu.fec_vencimiento < v_fecha /** Sólo cuotas vencidas. **/
               AND p.nro_cuenta = cc.nro_cuenta
               AND cc.relacion = 'P'
               AND nvl(p.dia_atraso, 0) > 0
               AND p.estado NOT IN ('N', 'I')
               AND (p.cod_modulo, p.cod_modalidad) IN
                   (SELECT d.cod_modulo, d.cod_modalidad
                      FROM ge_par_dinamicos d
                     WHERE d.parametro = 'MOD_COBRANZAS'
                       AND nvl(d.val_parametro, 'N') = 'S'
                       AND d.cod_modulo = 6
                       AND d.cod_modulo = p.cod_modulo
                       AND d.cod_modalidad = p.cod_modalidad)

            --AND p.cod_modalidad NOT IN (60, 650, 651, 652, 660) --modalidades no gestionables
            /*  and NOT EXISTS( select 1
             from ge_par_dinamicos x
            where x.parametro like 'COD_CAN_%' --Canales no Gestionables--
              and x.parametro not like 'COD_CAN_AGE_%'
              and x.val_parametro = to_char( p.cod_canal ) )*/
            UNION ALL
            /** Tarjetas.**/
            SELECT cc.cod_persona,
                   t.cod_modulo,
                   t.cod_modalidad,
                   t.cod_moneda,
                   t.cod_canal,
                   t.nro_cuenta,
                   t.dia_mora dia_atraso_cta,
                   0 nro_cuota,
                   t.dia_mora dia_atraso_cuota,
                   t.fec_vct_ult_cierre fec_vto_cuota,
                   CASE
                      WHEN t.sal_pag_minimo > t.mto_mora THEN
                       t.sal_pag_minimo
                      ELSE
                       t.mto_mora
                   END mto_mora_cuota
              FROM ge_cta_clientes cc, ta_cta_tarjetas t
             WHERE cc.cod_persona = p_cod_persona
               AND t.nro_cuenta = cc.nro_cuenta
               AND cc.relacion = 'P'
               AND nvl(t.dia_mora, 0) > 0
               AND t.estado <> 'C'
                  --AND t.cod_modalidad NOT IN (50, 51)
               AND (t.cod_modulo, t.cod_modalidad) IN
                   (SELECT d.cod_modulo, d.cod_modalidad
                      FROM ge_par_dinamicos d
                     WHERE d.parametro = 'MOD_COBRANZAS'
                       AND nvl(d.val_parametro, 'N') = 'S'
                       AND d.cod_modulo = 5
                       AND d.cod_modulo = t.cod_modulo
                       AND d.cod_modalidad = t.cod_modalidad)
               AND NOT EXISTS (SELECT 1
                      FROM ta_cobros co
                     WHERE co.nro_cuenta = t.nro_cuenta
                       AND co.fec_proceso >= v_fec_anterior /** Modificado por problemas con pagos tc online FCALVO 26/07/2010. **/
                          --and co.est_envio = 'P'
                       AND co.monto >= t.mto_mora
                       AND co.fec_valor > nvl(t.fec_ult_pago, '01/01/1900'))
            UNION ALL
            /** Operaciones Vencidas.**/
            SELECT t.cod_persona,
                   t.cod_modulo,
                   t.cod_modalidad,
                   m.cod_moneda,
                   NULL cod_canal,
                   m.nro_cta_origen nro_cuenta,
                   m.dia_atraso dia_atraso_cta,
                   0 nro_cuota,
                   nvl(m.dia_atraso, 0) dia_atraso_cuota,
                   NULL fec_vto_cuota,
                   m.sal_total mto_mora_cuota
              FROM ov_cta_vencidas m, ge_cta_clientes t
             WHERE t.cod_persona = p_cod_persona
               AND m.nro_cta_origen = t.nro_cuenta
               AND nvl(t.relacion, 'X') = 'P'
               AND nvl(m.dia_atraso, 0) > 0
               AND m.estado <> 'C'
               AND (m.cod_modulo, m.cod_modalidad) IN
                   (SELECT d.cod_modulo, d.cod_modalidad
                      FROM ge_par_dinamicos d
                     WHERE d.parametro = 'MOD_COBRANZAS'
                       AND nvl(d.val_parametro, 'N') = 'S'
                       AND d.cod_modulo = 15
                       AND d.cod_modulo = m.cod_modulo
                       AND d.cod_modalidad = m.cod_modalidad)
            UNION ALL
            /** Cuentas Corrientes.**/
            SELECT t.cod_persona,
                   x.cod_modulo,
                   x.cod_modalidad,
                   x.cod_moneda,
                   x.cod_canal,
                   x.nro_cuenta,
                   r.can_dias dia_atraso_cta,
                   0 nro_cuota,
                   nvl(r.can_dias, 0) dia_atraso_cuota,
                   NULL fec_vto_cuota,
                   x.sal_total mto_mora_cuota
              FROM cc_cta_corrientes x, ge_cta_clientes t, cc_sobregiros_res r
             WHERE t.cod_persona = p_cod_persona
               AND x.nro_cuenta = t.nro_cuenta
               AND x.nro_cuenta = r.nro_cuenta(+)
               AND nvl(t.relacion, 'X') = 'P'
               AND nvl(r.can_dias, 0) > 0
               AND x.estado = 'N'
               AND (x.cod_modulo, x.cod_modalidad) IN
                   (SELECT d.cod_modulo, d.cod_modalidad
                      FROM ge_par_dinamicos d
                     WHERE d.parametro = 'MOD_COBRANZAS'
                       AND nvl(d.val_parametro, 'N') = 'S'
                       AND d.cod_modulo = 4
                       AND d.cod_modulo = x.cod_modulo
                       AND d.cod_modalidad = x.cod_modalidad)
             ORDER BY dia_atraso_cta   DESC,
                      cod_modulo       DESC,
                      cod_modalidad    DESC,
                      nro_cuenta,
                      dia_atraso_cuota DESC;
         /*CURSOR detalle_bc IS
         SELECT cc.cod_persona,
                t.cod_modulo,
                t.cod_modalidad,
                t.cod_moneda,
                t.cod_canal,
                t.nro_cuenta,
                t.dia_mora dia_atraso_cta,
                0 nro_cuota,
                t.dia_mora dia_atraso_cuota,
                t.fec_vct_ult_cierre fec_vto_cuota,
                CASE
                   WHEN t.sal_pag_minimo > t.mto_mora THEN
                    t.sal_pag_minimo
                   ELSE
                    t.mto_mora
                END mto_mora_cuota
           FROM ge_cta_clientes cc, ta_cta_tarjetas t
          WHERE cc.cod_persona = p_cod_persona
            AND t.nro_cuenta = cc.nro_cuenta
            AND cc.relacion = 'P'
            AND nvl(t.dia_mora, 0) > 0
            AND t.estado <> 'C'
            AND t.cod_modalidad NOT IN (50, 51)
            AND NOT EXISTS (SELECT 1
                   FROM ta_cobros co
                  WHERE co.nro_cuenta = t.nro_cuenta
                    AND co.fec_proceso >= v_fec_anterior
                       --and co.est_envio = 'P'
                    AND co.monto >= t.mto_mora
                    AND co.fec_valor > nvl(t.fec_ult_pago, '01/01/1900'))
          ORDER BY dia_atraso_cta   DESC,
                   cod_modulo       DESC,
                   cod_modalidad    DESC,
                   nro_cuenta,
                   dia_atraso_cuota DESC;*/
      BEGIN
         v_fec_anterior := pag_cal.fu_obt_fec_ant_hab(v_fecha, 1);
         v_cabecera     := 0;
         INSERT INTO co_asignaciones
            (cod_persona, cod_tramo, tip_gestor, /*cod_gestor, */ fec_ini_asignacion, tip_segmento,
             cod_oficina, cod_usu_oficial)
         VALUES
            (p_cod_persona, p_cod_tramo, p_tip_gestor, /*'X', */ v_fecha, p_tip_segmento,
             p_cod_oficina, p_cod_usu_oficial);

         --IF p_cod_banca = 2 THEN
         FOR cuo IN detalle_bp LOOP
            IF v_cabecera = 0 THEN
               /** Indica que la cuota es prod. cabecera. **/
               v_cabecera := 1;
               INSERT INTO co_asignaciones_det
                  (cod_persona, fec_ini_asignacion, nro_cuenta, nro_cuota, cod_modulo,
                   cod_modalidad, cod_moneda, mto_atraso, fec_vto_cuota, dia_atraso, dia_ini_atraso,
                   pro_cabecera, cod_canal)
               VALUES
                  (cuo.cod_persona, v_fecha, cuo.nro_cuenta, cuo.nro_cuota, cuo.cod_modulo,
                   cuo.cod_modalidad, cuo.cod_moneda, cuo.mto_mora_cuota, cuo.fec_vto_cuota,
                   cuo.dia_atraso_cuota, cuo.dia_atraso_cuota, 'S', cuo.cod_canal);
            ELSE
               INSERT INTO co_asignaciones_det
                  (cod_persona, fec_ini_asignacion, nro_cuenta, nro_cuota, cod_modulo,
                   cod_modalidad, cod_moneda, mto_atraso, fec_vto_cuota, dia_atraso, dia_ini_atraso,
                   pro_cabecera, cod_canal)
               VALUES
                  (cuo.cod_persona, v_fecha, cuo.nro_cuenta, cuo.nro_cuota, cuo.cod_modulo,
                   cuo.cod_modalidad, cuo.cod_moneda, cuo.mto_mora_cuota, cuo.fec_vto_cuota,
                   cuo.dia_atraso_cuota, cuo.dia_atraso_cuota, 'N', cuo.cod_canal);
            END IF;
         END LOOP;
         /*ELSIF p_cod_banca <> 5 THEN
            FOR cuo IN detalle_bc LOOP
               IF v_cabecera = 0 THEN
                  \** Indica que la cuota es prod cabecera. **\
                  v_cabecera := 1;
                  INSERT INTO co_asignaciones_det
                     (cod_persona, fec_ini_asignacion, nro_cuenta, nro_cuota, cod_modulo,
                      cod_modalidad, cod_moneda, mto_atraso, fec_vto_cuota, dia_atraso,
                      dia_ini_atraso, pro_cabecera, cod_canal)
                  VALUES
                     (cuo.cod_persona, v_fecha, cuo.nro_cuenta, cuo.nro_cuota, cuo.cod_modulo,
                      cuo.cod_modalidad, cuo.cod_moneda, cuo.mto_mora_cuota, cuo.fec_vto_cuota,
                      cuo.dia_atraso_cuota, cuo.dia_atraso_cuota, 'S', cuo.cod_canal);
               ELSE
                  INSERT INTO co_asignaciones_det
                     (cod_persona, fec_ini_asignacion, nro_cuenta, nro_cuota, cod_modulo,
                      cod_modalidad, cod_moneda, mto_atraso, fec_vto_cuota, dia_atraso,
                      dia_ini_atraso, pro_cabecera, cod_canal)
                  VALUES
                     (cuo.cod_persona, v_fecha, cuo.nro_cuenta, cuo.nro_cuota, cuo.cod_modulo,
                      cuo.cod_modalidad, cuo.cod_moneda, cuo.mto_mora_cuota, cuo.fec_vto_cuota,
                      cuo.dia_atraso_cuota, cuo.dia_atraso_cuota, 'N', cuo.cod_canal);
               END IF;
            END LOOP;
         END IF;*/
      END lp_ins_tramo;

      /** Procedimiento de inserción de cuotas de Tramos. **/
      PROCEDURE lp_ins_cuo_tramo
      (
         p_cod_persona        IN VARCHAR2,
         p_cod_banca          IN NUMBER,
         p_fec_ini_asignacion IN DATE
      ) IS
         CURSOR detalle_bp IS
         /** Préstamos.**/
            SELECT cc.cod_persona,
                   p.cod_modulo,
                   p.cod_modalidad,
                   p.cod_moneda,
                   p.cod_canal,
                   p.nro_cuenta,
                   p.dia_atraso dia_atraso_cta,
                   cu.nro_cuota,
                   cu.fec_vencimiento,
                   v_fecha - cu.fec_vencimiento dia_atraso_cuota,
                   cu.fec_vencimiento fec_vto_cuota,
                   nvl(cu.sal_capital, 0) + nvl(cu.sal_interes, 0) + nvl(cu.sal_int_documentado, 0) mto_mora_cuota
              FROM pr_cta_prestamos p, ge_cta_clientes cc, pr_cuotas cu
             WHERE cc.cod_persona = p_cod_persona
               AND p.nro_cuenta = cu.nro_cuenta
               AND cu.nro_cuota > 0
               AND cu.estado <> 'N'
               AND cu.fec_vencimiento < v_fecha /** Sólo cuotas vencidas. **/
               AND p.nro_cuenta = cc.nro_cuenta
               AND cc.relacion = 'P'
               AND nvl(p.dia_atraso, 0) > 0
               AND p.estado NOT IN ('N', 'I')
               AND (p.cod_modulo, p.cod_modalidad) IN
                   (SELECT d.cod_modulo, d.cod_modalidad
                      FROM ge_par_dinamicos d
                     WHERE d.parametro = 'MOD_COBRANZAS'
                       AND nvl(d.val_parametro, 'N') = 'S'
                       AND d.cod_modulo = 6
                       AND d.cod_modulo = p.cod_modulo
                       AND d.cod_modalidad = p.cod_modalidad)
                  --AND p.cod_modalidad NOT IN (60, 650, 651, 652, 660) --modalidades no gestionables
                  /*  and NOT EXISTS( select 1
                   from ge_par_dinamicos x
                  where x.parametro like 'COD_CAN_%' --Canales no Gestionables--
                    and x.parametro not like 'COD_CAN_AGE_%'
                    and x.val_parametro = to_char( p.cod_canal ) )*/

               AND NOT EXISTS (SELECT 1
                      FROM co_asignaciones_det cd
                     WHERE cd.cod_persona = p_cod_persona
                       AND cd.fec_ini_asignacion = p_fec_ini_asignacion
                       AND cd.nro_cuenta = p.nro_cuenta
                       AND cd.nro_cuota = cu.nro_cuota)
            UNION ALL
            /** Tarjetas.**/
            SELECT cc.cod_persona,
                   t.cod_modulo,
                   t.cod_modalidad,
                   t.cod_moneda,
                   t.cod_canal,
                   t.nro_cuenta,
                   t.dia_mora,
                   0 nro_cuota,
                   t.fec_vct_ult_cierre,
                   t.dia_mora dia_atraso_cuota,
                   t.fec_vct_ult_cierre fec_vto_cuota,
                   CASE
                      WHEN t.sal_pag_minimo > t.mto_mora THEN
                       t.sal_pag_minimo
                      ELSE
                       t.mto_mora
                   END mto_mora_cuota
              FROM ge_cta_clientes cc, ta_cta_tarjetas t
             WHERE cc.cod_persona = p_cod_persona
               AND t.nro_cuenta = cc.nro_cuenta
               AND cc.relacion = 'P'
               AND nvl(t.dia_mora, 0) > 0
               AND t.estado <> 'C'
                  --AND t.cod_modalidad NOT IN (50, 51)
               AND (t.cod_modulo, t.cod_modalidad) IN
                   (SELECT d.cod_modulo, d.cod_modalidad
                      FROM ge_par_dinamicos d
                     WHERE d.parametro = 'MOD_COBRANZAS'
                       AND nvl(d.val_parametro, 'N') = 'S'
                       AND d.cod_modulo = 5
                       AND d.cod_modulo = t.cod_modulo
                       AND d.cod_modalidad = t.cod_modalidad)
               AND NOT EXISTS (SELECT 1
                      FROM co_asignaciones_det cd
                     WHERE cd.cod_persona = p_cod_persona
                       AND cd.fec_ini_asignacion = p_fec_ini_asignacion
                       AND cd.nro_cuenta = t.nro_cuenta)
               AND NOT EXISTS (SELECT 1
                      FROM ta_cobros co
                     WHERE co.nro_cuenta = t.nro_cuenta
                       AND co.fec_proceso >= v_fec_anterior
                          --and co.est_envio = 'P'
                       AND co.monto >= t.mto_mora
                       AND co.fec_valor > nvl(t.fec_ult_pago, '01/01/1900'))
            UNION ALL
            /** Operaciones Vencidas.**/
            SELECT t.cod_persona,
                   t.cod_modulo,
                   t.cod_modalidad,
                   m.cod_moneda,
                   NULL cod_canal,
                   m.nro_cta_origen nro_cuenta,
                   m.dia_atraso dia_atraso_cta,
                   0 nro_cuota,
                   NULL,
                   nvl(m.dia_atraso, 0) dia_atraso_cuota,
                   NULL fec_vto_cuota,
                   m.sal_total mto_mora_cuota
              FROM ov_cta_vencidas m, ge_cta_clientes t
             WHERE t.cod_persona = p_cod_persona
               AND m.nro_cta_origen = t.nro_cuenta
               AND nvl(t.relacion, 'X') = 'P'
               AND nvl(m.dia_atraso, 0) > 0
               AND m.estado <> 'C'
               AND (m.cod_modulo, m.cod_modalidad) IN
                   (SELECT d.cod_modulo, d.cod_modalidad
                      FROM ge_par_dinamicos d
                     WHERE d.parametro = 'MOD_COBRANZAS'
                       AND nvl(d.val_parametro, 'N') = 'S'
                       AND d.cod_modulo = 15
                       AND d.cod_modulo = m.cod_modulo
                       AND d.cod_modalidad = m.cod_modalidad)
               AND NOT EXISTS (SELECT 1 FROM co_asignaciones_det a
                               WHERE a.cod_persona = t.cod_persona
                                 AND a.fec_ini_asignacion = p_fec_ini_asignacion
                                 AND a.nro_cuenta = t.nro_cuenta
                                 AND a.nro_cuota = 0)
            UNION ALL
            /** Cuentas Corrientes.**/
            SELECT t.cod_persona,
                   x.cod_modulo,
                   x.cod_modalidad,
                   x.cod_moneda,
                   x.cod_canal,
                   x.nro_cuenta,
                   r.can_dias dia_atraso_cta,
                   0 nro_cuota,
                   NULL,
                   nvl(r.can_dias, 0) dia_atraso_cuota,
                   NULL fec_vto_cuota,
                   x.sal_total mto_mora_cuota
              FROM cc_cta_corrientes x, ge_cta_clientes t, cc_sobregiros_res r
             WHERE t.cod_persona = p_cod_persona
               AND x.nro_cuenta = t.nro_cuenta
               AND x.nro_cuenta = r.nro_cuenta(+)
               AND nvl(t.relacion, 'X') = 'P'
               AND nvl(r.can_dias, 0) > 0
               AND x.estado = 'N'
               AND (x.cod_modulo, x.cod_modalidad) IN
                   (SELECT d.cod_modulo, d.cod_modalidad
                      FROM ge_par_dinamicos d
                     WHERE d.parametro = 'MOD_COBRANZAS'
                       AND nvl(d.val_parametro, 'N') = 'S'
                       AND d.cod_modulo = 4
                       AND d.cod_modulo = x.cod_modulo
                       AND d.cod_modalidad = x.cod_modalidad)
               AND NOT EXISTS (SELECT 1 FROM co_asignaciones_det a
                                WHERE a.cod_persona        = t.cod_persona
                                  AND a.fec_ini_asignacion = p_fec_ini_asignacion
                                  AND a.nro_cuenta         = x.nro_cuenta
                                  AND a.nro_cuota          = 0)
             ORDER BY cod_persona, dia_atraso_cuota DESC;
         /*CURSOR detalle_bc IS
         SELECT cc.cod_persona,
                t.cod_modulo,
                t.cod_modalidad,
                t.cod_moneda,
                t.cod_canal,
                t.nro_cuenta,
                t.dia_mora,
                0 nro_cuota,
                t.fec_vct_ult_cierre,
                t.dia_mora dia_atraso_cuota,
                t.fec_vct_ult_cierre fec_vto_cuota,
                CASE
                   WHEN t.sal_pag_minimo > t.mto_mora THEN
                    t.sal_pag_minimo
                   ELSE
                    t.mto_mora
                END mto_mora_cuota
           FROM ge_cta_clientes cc, ta_cta_tarjetas t
          WHERE cc.cod_persona = p_cod_persona
            AND t.nro_cuenta = cc.nro_cuenta
            AND cc.relacion = 'P'
            AND nvl(t.dia_mora, 0) > 0
            AND t.estado <> 'C'
            AND t.cod_modalidad NOT IN (50, 51)
            AND NOT EXISTS (SELECT 1
                   FROM co_asignaciones_det cd
                  WHERE cd.cod_persona = p_cod_persona
                    AND cd.fec_ini_asignacion = p_fec_ini_asignacion
                    AND cd.nro_cuenta = t.nro_cuenta)
            AND NOT EXISTS (SELECT 1
                   FROM ta_cobros co
                  WHERE co.nro_cuenta = t.nro_cuenta
                    AND co.fec_proceso >= v_fec_anterior
                       --and co.est_envio = 'P'
                    AND co.monto >= t.mto_mora
                    AND co.fec_valor > nvl(t.fec_ult_pago, '01/01/1900'))
          ORDER BY cod_persona, dia_atraso_cuota DESC;*/
      BEGIN
         --IF p_cod_banca = 2 THEN
         FOR cuo IN detalle_bp LOOP
            INSERT INTO co_asignaciones_det
               (cod_persona, fec_ini_asignacion, nro_cuenta, nro_cuota, cod_modulo, cod_modalidad,
                cod_moneda, mto_atraso, fec_vto_cuota, dia_atraso, dia_ini_atraso, pro_cabecera,
                cod_canal)
            VALUES
               (cuo.cod_persona, p_fec_ini_asignacion, cuo.nro_cuenta, cuo.nro_cuota,
                cuo.cod_modulo, cuo.cod_modalidad, cuo.cod_moneda, cuo.mto_mora_cuota,
                cuo.fec_vto_cuota, cuo.dia_atraso_cuota, cuo.dia_atraso_cuota, 'N', cuo.cod_canal);
         END LOOP;
         /*ELSIF p_cod_banca <> 5 THEN
            FOR cuo IN detalle_bc LOOP
               INSERT INTO co_asignaciones_det
                  (cod_persona, fec_ini_asignacion, nro_cuenta, nro_cuota, cod_modulo,
                   cod_modalidad, cod_moneda, mto_atraso, fec_vto_cuota, dia_atraso, dia_ini_atraso,
                   pro_cabecera, cod_canal)
               VALUES
                  (cuo.cod_persona, p_fec_ini_asignacion, cuo.nro_cuenta, cuo.nro_cuota,
                   cuo.cod_modulo, cuo.cod_modalidad, cuo.cod_moneda, cuo.mto_mora_cuota,
                   cuo.fec_vto_cuota, cuo.dia_atraso_cuota, cuo.dia_atraso_cuota, 'N', cuo.cod_canal);
            END LOOP;
         END IF;*/
      END lp_ins_cuo_tramo;

      /************** PROCESO PRINCIPAL **************/
   BEGIN
      r_log.nom_proceso := 'PAO_COB.PR_GEN_ASIGNACIONES';
      r_log.hor_inicio  := SYSDATE;
      v_reg             := 0;
      pao_cob.pr_log('*** Inicio del proceso ***');
      IF ltrim(rtrim(upper(to_char(v_fecha, 'DAY')))) IN ('MONDAY', 'LUNES') THEN
         /** Si es lunes restar 2 dias habiles porque sabado no se corre el proceso. **/
         v_fec_cobros := pag_cal.fu_obt_fec_ant_hab(v_fecha, 1, 3);
      ELSE
         v_fec_cobros := pag_cal.fu_obt_fec_ant_hab(v_fecha, 1, 1);
      END IF;
      SELECT MAX(cd.fec_ult_pago) INTO v_fec_control FROM co_asignaciones_det cd;
      IF v_continuar = 'N' THEN
         IF v_fec_control = v_fec_cobros THEN
            /** Para asegurar que no corran 2 veces el proceso en el mismo dia. **/
            raise_application_error(-20000,
                                    'Error Cobros de Fecha ' || to_char(v_fec_cobros, 'DD/MM/YYYY') ||
                                     ' ya procesados. Verifique! ' || SQLERRM);
         END IF;
         v_lugar := 'Procesar cobros de Clientes';
         pao_cob.pr_log('*** 1. ' || v_lugar || ' ***');
         v_reg := 0;
         FOR cob IN cobros LOOP
            v_reg    := nvl(v_reg, 0) + 1;
            v_lugar  := 'Procesando Cobros del Cliente ' || cob.cod_persona;
            v_motivo := 'Regista cobro de fecha ' || to_char(cob.fec_cobro, 'DD/MM/YYYY') ||
                        ' en la cuenta cabecera';
            IF cob.mto_cobrado > cob.mto_atraso THEN
               v_mto_cobrado := cob.mto_atraso;
            ELSE
               v_mto_cobrado := cob.mto_cobrado;
            END IF;
            UPDATE co_asignaciones_det dt
               SET dt.mto_pagado   = dt.mto_pagado + v_mto_cobrado,
                   dt.fec_ult_pago = cob.fec_cobro
             WHERE dt.cod_persona = cob.cod_persona
               AND dt.fec_ini_asignacion = cob.fec_ini_asignacion
               AND dt.nro_cuenta = cob.nro_cuenta
               AND dt.nro_cuota = cob.nro_cuota;
            IF nvl(cob.mto_cobrado, 0) + nvl(cob.mto_pagado, 0) >= cob.mto_atraso AND
               cob.pro_cabecera = 'S' THEN
               /** Pago todo el producto cabecera, cancelar el tramo para que se vuelva a asignar. **/
               lp_can_tramo(cob.cod_persona, cob.fec_ini_asignacion, cob.cod_tramo, 'P');
               lp_can_agenda(cob.cod_agenda, v_motivo);
               IF (v_reg / 100) = round(v_reg / 100) THEN
                  r_log.nro_registro := v_reg;
                  pao_cob.pr_log('*** 1. Grabando ***');
               END IF;
               /** Para que no bloquee. **/
               COMMIT;
               ----
            END IF;
         END LOOP;
      END IF;
      v_lugar            := 'Generar asignaciones a clientes';
      r_log.nro_registro := NULL;
      pao_cob.pr_log('*** 2. ' || v_lugar || ' ***');
      v_reg := 0;
      FOR det IN c_clientes LOOP
         v_reg          := nvl(v_reg, 0) + 1;
         v_lugar        := 'Distribuir cliente' || to_char(det.cod_persona);
         v_cta_cabecera := pao_cob.fu_obt_cta_cabecera(det.cod_persona);
         IF nvl(v_cta_cabecera, 0) > 0 THEN
            /** Tiene una cuenta en mora. **/
            v_cod_tramo := pao_cob.fu_obt_tramo( /*det.tip_gru_cobranza, */ v_cta_cabecera);
            IF nvl(v_cod_tramo, 0) > 0 THEN
               v_tip_gestor := pao_cob.fu_obt_tip_gestor(v_cod_tramo);
               pao_cob.pr_ver_tra_actual(det.cod_persona, v_tra_actual, v_cod_agenda,
                                         v_fec_ini_asignacion, v_cta_cab_actual);
               v_lugar := 'Cliente ' || to_char(det.cod_persona) || ' sigue en mismo tramo';
               IF v_tra_actual IS NOT NULL AND v_tra_actual = v_cod_tramo THEN
                  /*IF v_cta_cab_actual <> v_cta_cabecera AND
                     v_cta_cab_actual IS NOT NULL THEN
                    v_lugar := 'Cliente ' || to_char( det.cod_persona ) || ' cambia producto cabecera, se cancela y se vuelve a asignar';
                    v_motivo := 'Cambia cuenta cabecera' || chr(10) ||
                                'Cta. Ant.: ' || v_cta_cab_actual || ' - ' || 'Cta. Act.: ' || v_cta_cabecera;
                    lp_can_tramo( det.cod_persona, v_fec_ini_asignacion, v_tra_actual, 'O' );
                    lp_can_agenda( v_cod_agenda, v_motivo );
                    lp_ins_tramo( det.cod_persona, det.cod_banca, v_cod_tramo, v_tip_gestor, det.tip_gru_cobranza );
                  ELSE*/
                  v_lugar := 'Cliente ' || to_char(det.cod_persona) ||
                             ' sigue en mismo tramo y no cambia producto cabecera, actualizar dias mora';
                  SELECT COUNT(*)
                    INTO v_realizado
                    FROM cr_agendas a
                   WHERE a.cod_agenda = v_cod_agenda
                     AND a.cod_estado = 2;
                  IF v_realizado = 1 AND v_tip_gestor NOT IN ('A', 'I') THEN
                     /** Volver a poner pendiente la actividad original de la agenda si no es tramo abogado. **/
                     UPDATE cr_agendas a
                        SET a.cod_estado    = 1,
                            a.fec_actividad = v_fecha
                      WHERE a.cod_agenda = v_cod_agenda;
                     /** Para que no bloquee. **/
                     COMMIT;
                     ------
                  END IF;
                  UPDATE co_asignaciones_det t
                     SET t.dia_atraso = v_fecha - t.fec_vto_cuota
                   WHERE t.cod_persona = det.cod_persona
                     AND t.fec_ini_asignacion = v_fec_ini_asignacion
                     AND t.cod_modulo = 6;
                  UPDATE co_asignaciones_det t
                     SET t.dia_atraso =
                         (SELECT greatest(v_fecha - x.fec_vct_ult_cierre, x.dia_mora)
                            FROM ta_cta_tarjetas x
                           WHERE x.nro_cuenta = t.nro_cuenta)
                   WHERE t.cod_persona = det.cod_persona
                     AND t.fec_ini_asignacion = v_fec_ini_asignacion
                     AND t.cod_modulo = 5;
                  v_lugar := 'Cliente ' || to_char(det.cod_persona) ||
                             ' insertar nuevas cuotas/cuentas si es necesario(dese el dia 1 p/prod indirecta)';
                  lp_ins_cuo_tramo(det.cod_persona, det.cod_banca, v_fec_ini_asignacion);
                  --          END IF;
               ELSIF v_tra_actual IS NOT NULL AND v_tra_actual <> v_cod_tramo THEN
                  v_lugar  := 'Cliente ' || to_char(det.cod_persona) ||
                              ' esta asignado pero cambia de tramo/ cancelar el actual e insertar el nuevo';
                  v_motivo := 'Supera cantidad de dias para el tramo';
                  /** VERIFICAR COBRO TOTAL DE LA CUENTA CABECERA. **/
                  BEGIN
                     SELECT 1
                       INTO v_cobro
                       FROM co_asignaciones t
                      WHERE t.cod_persona = det.cod_persona
                        AND t.fec_ini_asignacion = v_fec_ini_asignacion
                        AND t.fec_fin_asignacion = v_fecha
                        AND t.tip_baja = 'P';
                  EXCEPTION
                     WHEN no_data_found THEN
                        v_cobro := 0;
                  END;
                  IF v_cobro = 0 AND v_cod_tramo > v_tra_actual THEN
                     /** Para que mantenga el tipo de baja en P cuando tumba al tramo anterior. **/
                     lp_can_tramo(det.cod_persona, v_fec_ini_asignacion, v_tra_actual, 'T');
                     lp_can_agenda(v_cod_agenda, v_motivo);
                     /** Para que no bloquee. **/
                     COMMIT;
                     ----
                  ELSE
                     lp_can_tramo(det.cod_persona, v_fec_ini_asignacion, v_tra_actual, 'O');
                     lp_can_agenda(v_cod_agenda, v_motivo);
                     /** Para que no bloquee. **/
                     COMMIT;
                     ----
                  END IF;
                  lp_ins_tramo(det.cod_persona, det.cod_banca, v_cod_tramo, v_tip_gestor,
                               det.tip_gru_cobranza, det.cod_oficina, det.cod_usu_oficial);
               ELSIF v_tra_actual IS NULL THEN
                  v_lugar := 'Cliente ' || to_char(det.cod_persona) ||
                             ' no tiene asignacion y cumple las condiciones, se debe insertar';
                  lp_ins_tramo(det.cod_persona, det.cod_banca, v_cod_tramo, v_tip_gestor,
                               det.tip_gru_cobranza, det.cod_oficina, det.cod_usu_oficial);
               END IF;
            END IF;
         END IF;
         IF (v_reg / 100) = round(v_reg / 100) THEN
            r_log.nro_registro := v_reg;
            pao_cob.pr_log('*** 2. Grabando ***');
         END IF;
         /** Para que no bloquee. **/
         COMMIT;
         ----
      END LOOP;
      r_log.nro_registro := NULL;
      v_reg              := 0;
      pao_cob.pr_log('*** 3. Procesa tumbos ***');
      FOR tra IN c_tramos LOOP
         v_reg    := nvl(v_reg, 0) + 1;
         v_lugar  := 'Cliente ' || to_char(tra.cod_persona) ||
                     ' tiene tramo activo y ya no cumple las condiciones, se debe cancelar el tramo';
         v_motivo := 'Cliente ya no cumple condiciones.';
         IF pao_cob.fu_pue_age_cobranzas(tra.cod_persona, 'R') = 'N' THEN
            /*IF pao_cob.fu_pue_age_cobranzas(tra.cod_persona, 'R') = 'S'  AND
                                                                                                                                                                                                                                         nvl(pao_cob.fu_obt_tramo(tra.tip_gru_cobranza,
                                                                                                                                                                                                                                                                  pao_cob.fu_obt_cta_cabecera(tra.cod_persona)), 0) = 0
            THEN*/
            /*pao_cob.pr_ver_tra_actual(tra.cod_persona, v_tra_actual, v_cod_agenda,
                                            v_fec_ini_asignacion, v_cta_cab_actual);
                  lp_can_tramo(tra.cod_persona, v_fec_ini_asignacion, v_tra_actual, 'O'); --TIPO BAJA OTRO
                  lp_can_agenda(v_cod_agenda, v_motivo);
               END IF;
            ELSE*/
            v_cod_tramo := pao_cob.fu_obt_tramo( /*tra.tip_gru_cobranza, */ tra.cta_cabecera);
            IF nvl(v_cod_tramo, 0) = 0 THEN
               pao_cob.pr_ver_tra_actual(tra.cod_persona, v_tra_actual, v_cod_agenda,
                                         v_fec_ini_asignacion, v_cta_cab_actual);
               lp_can_tramo(tra.cod_persona, v_fec_ini_asignacion, v_tra_actual, 'O'); --TIPO BAJA OTRO
               lp_can_agenda(v_cod_agenda, v_motivo);
            END IF;
         END IF;
         IF (v_reg / 100) = round(v_reg / 100) THEN
            r_log.nro_registro := v_reg;
            pao_cob.pr_log('*** 3. Grabando ***');
         END IF;
         /** Para que no bloquee. **/
         COMMIT;
         ----
      END LOOP;
      r_log.nro_registro := NULL;
      r_log.hor_fin      := SYSDATE;
      pao_cob.pr_log('*** Proceso Finalizado ***');
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, v_lugar || '-' || SQLERRM);
   END pr_gen_asignaciones;

   /** Envío de Preventivas - Llama a pro_gen_inf_linea , inserta, hace update o borra de co_inf_cob_personas. **/
   PROCEDURE pr_gen_arc_preventivas IS
      /**
      || EFECTUA      : Proceso encargado de generar los archivos para enviar a Informconf la
      ||                información necesaria para la Gestión de Cobros por cuentas.
      ||                A la fecha son 3 archivos que se envían: Inclusión, Modificación y Exclusión,
      ||                los cuales tienen el mismo formato entre sí.
      ||                Se generan 2 juegos de archivos, uno para cuentas con días de mora hasta 180 días,
      ||                y otro para los que tengan más de 180 días de mora.
      **/
      /** Definiciones de Informconf:
      · Cuando se paga una cuota se debe informar como Modificación con el campo tip_inf_actualizacion
        = 'P' que significa pago. Si tenia varias cuotas en mora, y no pago todas, se debe volver a
        informar como Inclusión las cuotas que se deben seguir gestionando.
      · Si cae una nueva cuota en mora y el cliente ya se estaba informando, esta nueva cuota se informa
        como Modificación con el campo tip_inf_actualizacion = "D" (esto significa actualizar la deuda).
      · Se informa como Inclusión por el monto de pago mínimo o saldo en mora (según el que sea mayor),
        cuando el cliente cae en mora. **/
      /************************* PROCEDIMIENTOS PRIVADOS *************************/
      FUNCTION lf_obt_garantia
      (
         p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
         p_cod_modulo  ge_cuentas.cod_modulo%TYPE,
         p_observacion VARCHAR2
      ) RETURN NUMBER;

      PROCEDURE lp_obt_pago
      (
         p_nro_cuenta   IN ge_cuentas.nro_cuenta%TYPE,
         p_nro_cuota    IN pr_cuotas.nro_cuota%TYPE,
         p_cod_modulo   IN ge_cuentas.cod_modulo%TYPE,
         p_tip_cobro    OUT VARCHAR2,
         p_fec_ult_pago OUT DATE,
         p_mto_ult_pago OUT NUMBER,
         p_tip_informe  IN VARCHAR2,
         p_can_cuotas   IN pr_cuotas.nro_cuota%TYPE
      );
      /**************************** VARIABLES LOCALES ****************************/
      v_dir_par     ba_direcciones.direccion%TYPE;
      v_dir_lab     ba_direcciones.direccion%TYPE;
      v_dir_lab_alt ba_direcciones.direccion%TYPE;
      v_tel_par     VARCHAR2(20);
      v_tel_lab     VARCHAR2(20);
      /** Fecha actual del Módulo de Cobranzas. **/
      c_fec_actual CONSTANT DATE := fuo_fec_strategy;
      --c_fec_actual   DATE:= pag_cal.fu_obt_fec_actual(21);
      v_fec_control DATE;
      v_max_fecha   DATE;
      v_tel_lab_alt VARCHAR2(20);
      v_tip_cobro   VARCHAR2(1);
      v_fec_pago    DATE;
      v_mto_pago    NUMBER(18, 2);
      r_linea       co_inf_cob_personas%ROWTYPE;
      v_can_inf     NUMBER(20);
      v_can_sol     NUMBER(20);
      v_can_asignar NUMBER(20);
      v_old_nro_cta ge_cuentas.nro_cuenta%TYPE;
      v_old_nro_cuo NUMBER(5);
      v_fec_ult_env DATE;
      v_nro         VARCHAR2(50);
      v_regs        NUMBER;
      v_mensaje     VARCHAR2(2000);
      v_error EXCEPTION;
      v_existe      NUMBER;
      v_estado      VARCHAR2(1);
      v_nro_1       NUMBER(18);
      v_mto_pagado  NUMBER(18, 2);
      v_dias_atraso NUMBER(4);
      v_cantidad    NUMBER(4);
      /** Carga de Cursores. **/
      CURSOR inclusiones(p_nuevos VARCHAR2) IS
      /** Prestamos. **/
         SELECT *
           FROM (SELECT DISTINCT p.cod_persona,
                                 c.nro_cuenta,
                                 substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'),
                                        1, 15) nro_documento,
                                 c.cod_modulo,
                                 substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                                 substr(f.seg_nombre, 1, 15) seg_nombre,
                                 substr(f.pri_apellido, 1, 20) pri_apellido,
                                 substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                                   pao_mor.fu_obt_ape_casada(f.cod_persona)),
                                            f.seg_apellido), 1, 20) seg_apellido,
                                 decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                        substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                                 c.fec_inicio fec_operacion,
                                 1 tip_operacion,
                                 (SELECT MIN(pr.nro_cuota)
                                    FROM pr_cuotas pr
                                   WHERE pr.nro_cuenta = u.nro_cuenta
                                     AND nvl(pr.nro_cuota, 0) > 0
                                     AND nvl(pr.estado, 'x') <> 'N'
                                     AND pr.fec_vencimiento <= c_fec_actual) nro_cuota,
                                 c.can_cuotas,
                                 decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                                 (nvl(u.mto_capital, 0) + nvl(u.mto_interes, 0)) mto_cuota,
                                 to_date(NULL, 'DD/MM/YYYY') fec_final,
                                 NULL tip_actualizacion,
                                 'M' periodicidad,
                                 z.pri_cuo_atr pri_cuo_atrasada,
                                 z.can_cuo_atr can_cuo_atrasada,
                                 z.pri_fec_ven_atr pri_fec_ven_atrasada,
                                 b.fec_ult_pago,
                                 z.sal_cuo_mora sal_mora,
                                 c.cod_modalidad,
                                 c.cod_moneda,
                                 'INC-1.1' observacion,
                                 0 dias_atraso,
                                 NULL nro_cta_nueva,
                                 NULL cod_ori_modulo,
                                 NULL cod_ori_modalidad,
                                 c.cod_sec_credito
                   FROM pr_cta_prestamos c,
                        ge_cta_clientes t,
                        ge_clientes l,
                        ba_personas p,
                        ba_per_fisicas f,
                        ba_per_juridicas j,
                        pr_cuotas u,
                        ge_est_cuentas e,
                        ge_par_dinamicos o,
                        ge_cuentas w,
                        (SELECT x.nro_cuenta nro_cta, MAX(x.fecha) fec_ult_pago
                           FROM pr_cobros x
                          WHERE x.fecha >= v_fec_ult_env
                            AND nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                                nvl(x.mto_int_documentado, 0) > 0
                          GROUP BY x.nro_cuenta) b,
                        (SELECT x.nro_cuenta nro_cta,
                                MIN(x.nro_cuota) pri_cuo_atr,
                                COUNT(*) can_cuo_atr,
                                MIN(x.fec_vencimiento) pri_fec_ven_atr,
                                SUM(nvl(x.sal_capital, 0) + nvl(x.sal_interes, 0) +
                                    nvl(x.sal_int_documentado, 0)) sal_cuo_mora
                           FROM pr_cuotas x
                          WHERE x.nro_cuenta IS NOT NULL
                            AND x.nro_cuota <> 0
                            AND x.estado <> 'N'
                               /** No incluir las cuotas con menos de 60 días de atraso. **/
                            AND x.fec_vencimiento + nvl(v_dia_atr_ini_pre_informconf, 0) <=
                                c_fec_actual
                          GROUP BY x.nro_cuenta) z
                  WHERE c.nro_cuenta = t.nro_cuenta
                    AND t.nro_cuenta = w.nro_cuenta
                       /** No debe de enviar cuentas judicializadas. **/
                    --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
                    AND fu_ver_cli_judicial(l.cod_persona) = 'N'
                    AND l.cod_persona = t.cod_persona
                    AND nvl(t.relacion, 'x') = 'P'
                       --x AND ((c.dia_atraso >= nvl( v_dia_atr_ini_pre_informconf,0) and l.cli_especial = 'N') OR
                       --x      (c.dia_atraso >= nvl( v_dia_atr_vip_cob_tercerizadas,0) and l.cli_especial = 'S'))
                    AND l.cod_persona = p.cod_persona
                    AND l.cod_persona = f.cod_persona(+)
                    AND l.cod_persona = j.cod_persona(+)
                    AND c.nro_cuenta = u.nro_cuenta
                    AND nvl(u.nro_cuota, 0) > 0
                    AND nvl(u.estado, 'x') <> 'N'
                    AND u.fec_vencimiento <= c_fec_actual
                    AND u.nro_cuenta = b.nro_cta(+)
                    AND c.nro_cuenta = z.nro_cta
                    AND nvl(z.sal_cuo_mora, 0) > v_sal_min_pre_cobranzas
                    AND nvl(z.sal_cuo_mora, 0) <= v_sal_max_pre_cobranzas
                    AND c.cod_modulo = e.cod_modulo
                    AND c.cod_modalidad = e.cod_modalidad
                    AND c.estado = e.estado
                    AND e.activo = 'S'
                    AND c.estado <> 'I'
                       /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
                       Debe ser nulo o Pertenecer a cualquier Banca, si se desea enviar mas
                       bancas en un futuro se debe de incluir en el par_dinamico(TIP_BAN_INFORMCONF) ej.(1,2,3,...etc.) para el IN. **/
                    AND l.cod_usu_oficial IN
                        (SELECT cod_usuario
                           FROM ba_usuarios
                          WHERE oficial = 'S'
                            AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                                cod_banca IS NULL))
                       /** Módulo y Modalidad a enviar(MOD_COBRANZA='S'). **/
                    AND o.parametro = 'MOD_COBRANZAS'
                    AND nvl(o.val_parametro, 'N') = 'S'
                    AND o.cod_modulo = c.cod_modulo
                    AND o.cod_modalidad = c.cod_modalidad
                       --***************************
                    AND NOT EXISTS (SELECT 1
                           FROM pr_cta_garantias x
                          WHERE x.nro_cuenta = c.nro_cuenta
                            AND x.cod_garantia = 5)
                    AND NOT EXISTS (SELECT 1
                           FROM co_inf_cob_personas x
                          WHERE x.cod_persona = l.cod_persona
                            AND x.nro_cuenta = c.nro_cuenta)
                       /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
                    AND NOT EXISTS (SELECT 1
                           FROM ba_usuarios u
                          WHERE u.cod_persona = l.cod_persona
                            AND nvl(u.estado, 'A') = 'A')
                       /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
                    AND NOT EXISTS (SELECT 1
                           FROM ge_tra_prohibidas z
                          WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                            AND z.cod_modulo = c.cod_modulo
                            AND z.cod_modalidad = c.cod_modalidad
                            AND z.nro_cuenta = c.nro_cuenta)
                       /** Para que excluya los que no se envian a informconf
                       deben tener marcado env_informconf como 'N' EN BA_PER_DAT_ADICIONALES. **/
                    AND p.cod_persona NOT IN
                        (SELECT cod_persona
                           FROM ba_per_dat_adicionales
                          WHERE parametro LIKE 'ENV_INFORMCONF'
                            AND nvl(val_parametro, 'S') = 'N')
                       /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
                    AND NOT EXISTS
                  (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
                 UNION ALL
                 /**Refinanciación y Reestructuración**/
                SELECT DISTINCT p.cod_persona,
                                         c.nro_cuenta,
                                         substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                                         c.cod_modulo,
                                         substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                                         substr(f.seg_nombre, 1, 15) seg_nombre,
                                         substr(f.pri_apellido, 1, 20) pri_apellido,
                                         substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                                           pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido),
                                                1, 20) seg_apellido,
                                         decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                                substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                                         c.fec_inicio fec_operacion,
                                         1 tip_operacion,
                                         (SELECT MIN(pr.nro_cuota)
                                            FROM pr_cuotas pr
                                           WHERE pr.nro_cuenta = u.nro_cuenta
                                             AND nvl(pr.nro_cuota, 0) > 0
                                             AND nvl(pr.estado, 'x') <> 'N'
                                             AND pr.fec_vencimiento <= c_fec_actual) nro_cuota,
                                         c.can_cuotas,
                                         decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                                         (nvl(u.mto_capital, 0) + nvl(u.mto_interes, 0)) mto_cuota,
                                         to_date(NULL, 'DD/MM/YYYY') fec_final,
                                         NULL tip_actualizacion,
                                         'M' periodicidad,
                                         z.pri_cuo_atr pri_cuo_atrasada,
                                         z.can_cuo_atr can_cuo_atrasada,
                                         z.pri_fec_ven_atr pri_fec_ven_atrasada,
                                         b.fec_ult_pago,
                                         z.sal_cuo_mora sal_mora,
                                         c.cod_modalidad,
                                         c.cod_moneda,
                                         'INC-1.1' observacion,
                                         0 dias_atraso,
                                         NULL nro_cta_nueva,
                                         NULL cod_ori_modulo,
                                         NULL cod_ori_modalidad,
                                         c.cod_sec_credito
                           FROM pr_cta_prestamos c,
                                ge_cta_clientes t,
                                ge_clientes l,
                                ba_personas p,
                                ba_per_fisicas f,
                                ba_per_juridicas j,
                                pr_cuotas u,
                                ge_est_cuentas e,
                                ge_par_dinamicos o,
                                ge_cuentas w,
                                (SELECT x.nro_cuenta nro_cta, MAX(x.fecha) fec_ult_pago
                                   FROM pr_cobros x
                                  WHERE x.fecha >= v_fec_ult_env
                                    AND nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                                        nvl(x.mto_int_documentado, 0) > 0
                                  GROUP BY x.nro_cuenta) b,
                                (SELECT x.nro_cuenta nro_cta,
                                        MIN(x.nro_cuota) pri_cuo_atr,
                                        COUNT(*) can_cuo_atr,
                                        MIN(x.fec_vencimiento) pri_fec_ven_atr,
                                        SUM(nvl(x.sal_capital, 0) + nvl(x.sal_interes, 0) +
                                            nvl(x.sal_int_documentado, 0)) sal_cuo_mora
                                   FROM pr_cuotas x
                                  WHERE x.nro_cuenta IS NOT NULL
                                    AND x.nro_cuota <> 0
                                    AND x.estado <> 'N'

                   /*                    \** No incluir las cuotas con menos de 60 días de atraso. **\
                                    AND x.fec_vencimiento + nvl(:v_dia_atr_ini_pre_informconf, 0) <= :c_fec_actual*/
                                  GROUP BY x.nro_cuenta) z
                          WHERE c.nro_cuenta = t.nro_cuenta
                            AND t.nro_cuenta = w.nro_cuenta
                            AND c.tip_renovacion in ('R','E')
                               /** No debe de enviar cuentas judicializadas. **/
                            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
                            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
                            AND l.cod_persona = t.cod_persona
                            AND nvl(t.relacion, 'x') = 'P'
                            AND ((nvl(c.dia_atraso, 0) >= nvl(v_dia_atr_ini_pre_informconf, 0) AND
                                l.cli_especial = 'N') OR
                                (nvl(c.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                                l.cli_especial = 'S'))
                            AND l.cod_persona = p.cod_persona
                            AND l.cod_persona = f.cod_persona(+)
                            AND l.cod_persona = j.cod_persona(+)
                            AND c.nro_cuenta = u.nro_cuenta
                            AND nvl(u.nro_cuota, 0) > 0
                            AND nvl(u.estado, 'x') <> 'N'
                            AND u.fec_vencimiento <= c_fec_actual
                            AND u.nro_cuenta = b.nro_cta(+)
                            AND c.nro_cuenta = z.nro_cta
                         /*   AND nvl(z.sal_cuo_mora, 0) > :v_sal_min_pre_cobranzas
                            AND nvl(z.sal_cuo_mora, 0) <= :v_sal_max_pre_cobranzas*/
                            AND c.cod_modulo = e.cod_modulo
                            AND c.cod_modalidad = e.cod_modalidad
                            AND c.estado = e.estado
                            AND e.activo = 'S'
                            AND c.estado <> 'I'
                               /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
                               Debe ser nulo o Pertenecer a cualquier Banca, si se desea enviar mas
                               bancas en un futuro se debe de incluir en el par_dinamico(TIP_BAN_INFORMCONF) ej.(1,2,3,...etc.) para el IN. **/
                            AND l.cod_usu_oficial IN
                                (SELECT cod_usuario
                                   FROM ba_usuarios
                                  WHERE oficial = 'S'
                                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                                        cod_banca IS NULL))
                               /** Módulo y Modalidad a enviar(MOD_COBRANZA='S'). **/
                            AND o.parametro = 'MOD_COBRANZAS'
                            AND nvl(o.val_parametro, 'N') = 'S'
                            AND o.cod_modulo = c.cod_modulo
                            AND o.cod_modalidad = c.cod_modalidad
                               --***************************
                            AND NOT EXISTS (SELECT 1
                                   FROM pr_cta_garantias x
                                  WHERE x.nro_cuenta = c.nro_cuenta
                                    AND x.cod_garantia = 5)
                            AND NOT EXISTS (SELECT 1
                                   FROM co_inf_cob_personas x
                                  WHERE x.cod_persona = l.cod_persona
                                    AND x.nro_cuenta = c.nro_cuenta)
                               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
                            AND NOT EXISTS (SELECT 1
                                   FROM ba_usuarios u
                                  WHERE u.cod_persona = l.cod_persona
                                    AND nvl(u.estado, 'A') = 'A')
                               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
                            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
                               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
                            AND NOT EXISTS
                          (SELECT 1
                                   FROM ge_tra_prohibidas z
                                  WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                                    AND z.cod_modulo = c.cod_modulo
                                    AND z.cod_modalidad = c.cod_modalidad
                                    AND z.nro_cuenta = c.nro_cuenta)
                               /** Para que excluya los que no se envian a informconf
                               deben tener marcado env_informconf como 'N' EN BA_PER_DAT_ADICIONALES. **/
                            AND p.cod_persona NOT IN (SELECT cod_persona
                                                        FROM ba_per_dat_adicionales
                                                       WHERE parametro LIKE 'ENV_INFORMCONF'
                                                         AND nvl(val_parametro, 'S') = 'N')
                 UNION ALL
                 /** Tarjetas.**/
                 SELECT p.cod_persona,
                        c.nro_cuenta,
                        substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                        c.cod_modulo,
                        substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                        substr(f.seg_nombre, 1, 15) seg_nombre,
                        substr(f.pri_apellido, 1, 20) pri_apellido,
                        substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                          pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido),
                               1, 20) seg_apellido,
                        decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                               substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                        c.fec_apertura fec_operacion,
                        3 tip_operacion,
                        0 nro_cuota,
                        NULL can_cuotas,
                        decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                        decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1,
                               nvl(c.mto_mora, 0),
                               /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                               nvl(c.mto_mora, 0),
                               /** Si el pago minimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                               nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)) mto_cuota,
                        to_date(NULL, 'DD/MM/YYYY') fec_final,
                        ' ' tip_actualizacion,
                        'M' periodicidad,
                        NULL pri_cuo_atrasada,
                        1 can_cuo_atrasada,
                        (c_fec_actual - nvl(c.dia_mora, 0)) pri_fec_ven_atrasada,
                        MAX(b.fec_proceso) fec_ult_pago,
                        decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1,
                               nvl(c.mto_mora, 0),
                               /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                               nvl(c.mto_mora, 0),
                               /** Si el pago minimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                               nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)) sal_mora,
                        c.cod_modalidad,
                        c.cod_moneda,
                        'INC-1.2' observacion,
                        0 dias_atraso,
                        NULL nro_cta_nueva,
                        NULL cod_ori_modulo,
                        NULL cod_ori_modalidad,
                        NULL cod_sec_credito
                   FROM ta_cta_tarjetas  c,
                        ge_cta_clientes  t,
                        ge_clientes      l,
                        ba_personas      p,
                        ba_per_fisicas   f,
                        ba_per_juridicas j,
                        ta_cobros        b,
                        ge_est_cuentas   e,
                        ge_par_dinamicos o,
                        ge_cuentas       w
                  WHERE c.nro_cuenta = t.nro_cuenta
                    AND l.cod_persona = t.cod_persona
                    AND nvl(t.relacion, 'x') = 'P'
                       --x AND ((nvl(c.dia_mora,0) >= nvl( v_dia_atr_ini_tar_informconf,0) and l.cli_especial = 'N') OR
                       --x     (c.dia_mora >= nvl( v_dia_atr_vip_cob_tercerizadas,0) and l.cli_especial = 'S'))
                       --x AND nvl(c.mto_mora, 0) > nvl(v_sal_min_tar_cob_informconf, 0)
                       --x AND nvl(c.mto_mora, 0) <= nvl(v_sal_max_tar_cobranzas, 0)
                    AND l.cod_persona = p.cod_persona
                    AND l.cod_persona = f.cod_persona(+)
                    AND l.cod_persona = j.cod_persona(+)
                    AND c.nro_cuenta = b.nro_cuenta(+)
                    AND nvl(b.fec_proceso(+), c_fec_actual) >= v_fec_ult_env
                    AND c.cod_modulo = e.cod_modulo
                    AND c.cod_modalidad = e.cod_modalidad
                    AND c.estado = e.estado
                    AND t.nro_cuenta = w.nro_cuenta
                       /** No debe de enviar cuentas judicializadas. **/
                    --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
                    AND fu_ver_cli_judicial(l.cod_persona) = 'N'
                    AND e.activo = 'S'
                    AND c.estado <> 'I'
                    --AND nvl(c.en_juicio, 'N') = 'N' V.O. 17-10-13
                       /** Por Módulo y Modalidad, por par_dinamico(MOD_COBRANZAS). **/
                    AND o.parametro = 'MOD_COBRANZAS'
                    AND nvl(o.val_parametro, 'N') = 'S'
                    AND o.cod_modulo = c.cod_modulo
                    AND o.cod_modalidad = c.cod_modalidad
                       /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
                       Debe ser nulo o Pertenecer a cualquier Banca. **/
                    AND l.cod_usu_oficial IN
                        (SELECT cod_usuario
                           FROM ba_usuarios
                          WHERE oficial = 'S'
                            AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                                cod_banca IS NULL))
                       --***************************
                    AND NOT EXISTS (SELECT 1
                           FROM co_inf_cob_personas x
                          WHERE x.cod_persona = l.cod_persona
                            AND x.nro_cuenta = c.nro_cuenta
                            AND x.nro_cuota = 0)
                       /** No incluir en la Gestión de Cobranzas a los funcionarios. **/
                    AND NOT EXISTS (SELECT 1
                           FROM ba_usuarios u
                          WHERE u.cod_persona = l.cod_persona
                            AND nvl(u.estado, 'A') = 'A')
                       /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
                    AND NOT EXISTS
                  (SELECT 1
                           FROM ge_tra_prohibidas z
                          WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                            AND z.cod_modulo = c.cod_modulo
                            AND z.cod_modalidad = c.cod_modalidad
                            AND z.nro_cuenta = c.nro_cuenta)
                       /** Para que excluya los que no se envian a informconf. **/
                       /** Deben tener marcado env_informconf como 'N' EN BA_PER_DAT_ADICIONALES. **/
                    AND p.cod_persona NOT IN (SELECT cod_persona
                                                FROM ba_per_dat_adicionales
                                               WHERE parametro LIKE 'ENV_INFORMCONF'
                                                 AND val_parametro = 'N')
                       /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
                    AND NOT EXISTS
                  (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
                  GROUP BY p.cod_persona,
                           c.nro_cuenta,
                           substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15),
                           c.cod_modulo,
                           substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65),
                           substr(f.seg_nombre, 1, 15),
                           substr(f.pri_apellido, 1, 20),
                           substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                             pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido),
                                  1, 20),
                           decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                  substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)),
                           c.fec_apertura,
                           3,
                           0,
                           NULL,
                           decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D'),
                           nvl(c.mto_pag_minimo, 0),
                           to_date(NULL, 'DD/MM/YYYY'),
                           ' ',
                           NULL,
                           NULL,
                           NULL,
                           (c_fec_actual - nvl(c.dia_mora, 0)),
                           decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1,
                                  nvl(c.mto_mora, 0),
                                  /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                                  nvl(c.mto_mora, 0),
                                  /** Si el pago minimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                                  nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)),
                           c.cod_modalidad,
                           c.cod_moneda
                 /** Agregado para sobregiros.**/
                 UNION ALL
                 SELECT DISTINCT p.cod_persona,
                                 m.nro_cta_origen nro_cuenta, --m.nro_cuenta,
                                 substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'),
                                        1, 15) nro_documento,
                                 4 cod_modulo,
                                 substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                                 substr(f.seg_nombre, 1, 15) seg_nombre,
                                 substr(f.pri_apellido, 1, 20) pri_apellido,
                                 substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                                   pao_mor.fu_obt_ape_casada(f.cod_persona)),
                                            f.seg_apellido), 1, 20) seg_apellido,
                                 decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                        substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                                 (c_fec_actual - m.dia_atraso) fec_operacion,
                                 4 tip_operacion,
                                 0 nro_cuota,
                                 NULL can_cuotas,
                                 decode(nvl(w.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                                 0 mto_cuota,
                                 NULL fec_final,
                                 ' ' tip_actualizacion,
                                 'M' periodicidad,
                                 NULL pri_cuo_atrasada,
                                 1 can_cuo_atrasada,
                                 NULL pri_fec_ven_atrasada,
                                 NULL fec_ult_pago,
                                 m.sal_total sal_mora,
                                 41 cod_modalidad,
                                 w.cod_moneda,
                                 'INC-1.3' observacion,
                                 m.dia_atraso dias_atraso,
                                 m.nro_cuenta nro_cta_nueva,
                                 15 cod_ori_modulo,
                                 152 cod_ori_modalidad,
                                 NULL cod_sec_credito
                   FROM ov_cta_vencidas  m,
                        ge_cta_clientes  t,
                        ge_clientes      l,
                        ba_personas      p,
                        ba_per_fisicas   f,
                        ba_per_juridicas j,
                        ge_cuentas       w,
                        ge_est_cuentas   e
                  WHERE m.nro_cta_origen = t.nro_cuenta
                    AND t.cod_persona = l.cod_persona
                    AND l.cod_persona = p.cod_persona
                    AND l.cod_persona = f.cod_persona(+)
                    AND l.cod_persona = j.cod_persona(+)
                    AND t.nro_cuenta = w.nro_cuenta
                    AND w.cod_modulo = e.cod_modulo
                    AND w.cod_modalidad = e.cod_modalidad
                    AND m.cod_modulo = 15
                    AND m.cod_modalidad = 152
                    AND nvl(m.sal_total, 0) > nvl(v_sal_min_sob_cobranzas, 0)
                    AND nvl(m.sal_total, 0) <= v_sal_max_sob_cobranzas
                       --x AND nvl(m.dia_atraso, 0) >= v_dia_atr_ini_pre_informconf
                    AND nvl(t.relacion, 'x') = 'P'
                    AND m.estado <> 'C'
                       --*****************************************************************
                       /** No debe enviar los que ya fueron enviados en CC_CTA_CORRIENTES. **/
                    AND NOT EXISTS
                  (SELECT 1
                           FROM co_inf_cob_diarios f
                          WHERE f.nro_cuenta = m.nro_cta_origen
                            AND f.cod_modulo = 4
                            AND f.cod_modalidad = 41
                            AND f.fec_envio < c_fec_actual)
                       /** Para parametro de mto_mora. **/
                       --x AND ((nvl(m.dia_atraso, 0) >= nvl(v_dia_atr_ini_tar_informconf, 0) AND
                       --x     l.cli_especial = 'N') OR
                       --x     (nvl(m.dia_atraso, 0) >= nvl(v_dia_atr_ini_sob_informconf, 0) AND
                       --x     l.cli_especial = 'S'))
                       /** No debe de enviar cuentas judicializadas. **/
                    --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
                    AND fu_ver_cli_judicial(l.cod_persona) = 'N'
                    AND e.activo = 'S'
                       /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
                       Debe ser nulo o Pertenecer a cualquier Banca. **/
                    AND l.cod_usu_oficial IN
                        (SELECT cod_usuario
                           FROM ba_usuarios
                          WHERE oficial = 'S'
                            AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                                cod_banca IS NULL))
                    AND NOT EXISTS (SELECT 1
                           FROM co_inf_cob_personas s
                          WHERE s.cod_persona = l.cod_persona
                            AND s.nro_cuenta = m.nro_cta_origen
                            AND s.nro_cuota = 0)
                       /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
                    AND NOT EXISTS
                  (SELECT 1
                           FROM ge_tra_prohibidas z
                          WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                            AND z.cod_modulo = w.cod_modulo
                            AND z.cod_modalidad = w.cod_modalidad
                            AND z.nro_cuenta = w.nro_cuenta)
                       /** Para que excluya los que no se envian a informconf. **/
                    AND p.cod_persona NOT IN (SELECT cod_persona
                                                FROM ba_per_dat_adicionales
                                               WHERE parametro LIKE 'ENV_INFORMCONF'
                                                 AND val_parametro = 'N')
                       /** No incluir en la Gestión de Cobranzas a los funcionarios. **/
                    AND NOT EXISTS (SELECT 1
                           FROM ba_usuarios u
                          WHERE u.cod_persona = l.cod_persona
                            AND nvl(u.estado, 'A') = 'A')
                       /** No incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
                    AND NOT EXISTS
                  (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
                 UNION ALL
                 /** Agregado para Tarjetas Vencidas.**/
                 SELECT DISTINCT p.cod_persona,
                                 s.nro_cta_origen nro_cuenta, ---s.nro_cuenta,
                                 substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'),
                                        1, 15) nro_documento,
                                 5 cod_modulo,
                                 substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                                 substr(f.seg_nombre, 1, 15) seg_nombre,
                                 substr(f.pri_apellido, 1, 20) pri_apellido,
                                 substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                                   pao_mor.fu_obt_ape_casada(f.cod_persona)),
                                            f.seg_apellido), 1, 20) seg_apellido,
                                 decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                        substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                                 (c_fec_actual - s.dia_atraso) fec_operacion,
                                 3 tip_operacion,
                                 0 nro_cuota,
                                 NULL can_cuotas,
                                 decode(nvl(w.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                                 0 mto_cuota,
                                 NULL fec_final,
                                 ' ' tip_actualizacion,
                                 'M' periodicidad,
                                 NULL pri_cuo_atrasada,
                                 1 can_cuo_atrasada,
                                 NULL pri_fec_ven_atrasada,
                                 NULL fec_ult_pago,
                                 s.sal_total sal_mora,
                                 51 cod_modalidad,
                                 w.cod_moneda,
                                 'INC-1.4' observacion,
                                 s.dia_atraso dias_atraso,
                                 s.nro_cuenta nro_cta_nueva,
                                 15 cod_ori_modulo,
                                 151 cod_ori_modalidad,
                                 NULL cod_sec_credito
                   FROM ov_cta_vencidas  s,
                        ge_cta_clientes  t,
                        ge_clientes      l,
                        ba_personas      p,
                        ba_per_fisicas   f,
                        ba_per_juridicas j,
                        ge_cuentas       w,
                        ge_est_cuentas   e
                  WHERE s.nro_cta_origen = w.nro_cuenta
                    AND s.nro_cta_origen = t.nro_cuenta
                    AND s.cod_modulo = 15
                    AND s.cod_modalidad = 151
                    AND t.relacion IN ('P')
                    AND s.estado <> 'C'
                       --*****************************************************************
                       /** WA:No debe enviar los que ya fueron enviados en TA_CTA_TARJETAS. **/
                    AND NOT EXISTS
                  (SELECT 1
                           FROM co_inf_cob_diarios f
                          WHERE f.nro_cuenta = s.nro_cta_origen
                            AND f.cod_modulo = 5
                            AND f.fec_envio < c_fec_actual)
                    AND t.cod_persona = l.cod_persona
                    AND l.cod_persona = p.cod_persona
                    AND l.cod_persona = f.cod_persona(+)
                    AND l.cod_persona = j.cod_persona(+)
                    AND t.nro_cuenta = w.nro_cuenta
                    AND s.cod_modulo = e.cod_modulo
                    AND s.cod_modalidad = e.cod_modalidad
                    AND nvl(t.relacion, 'x') = 'P'
                       /** Para parametro de mto_mora. **/
                    AND nvl(s.sal_total, 0) > nvl(v_sal_min_tar_cob_informconf, 0)
                    AND nvl(s.sal_total, 0) <= v_sal_max_tar_cobranzas
                       --xAND ((s.dia_atraso >= nvl( v_dia_atr_ini_tar_informconf,0) and l.cli_especial = 'N') OR
                       --x     (s.dia_atraso >= nvl( v_dia_atr_vip_cob_tercerizadas,0) and l.cli_especial = 'S'))
                       /** No debe de enviar cuentas judicializadas. **/
                    --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
                    AND fu_ver_cli_judicial(l.cod_persona) = 'N'
                    AND e.activo = 'S'
                       /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
                       Debe ser nulo o Pertenecer a cualquier Banca. **/
                    AND l.cod_usu_oficial IN
                        (SELECT cod_usuario
                           FROM ba_usuarios
                          WHERE oficial = 'S'
                            AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                                cod_banca IS NULL))
                    AND NOT EXISTS (SELECT 1
                           FROM co_inf_cob_personas z
                          WHERE z.cod_persona = l.cod_persona
                            AND z.nro_cuenta = s.nro_cta_origen --s.nro_cuenta
                            AND z.nro_cuota = 0
                            AND z.observacion = 'INC-1.4')
                       /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
                    AND NOT EXISTS
                  (SELECT 1
                           FROM ge_tra_prohibidas z
                          WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                            AND z.cod_modulo = w.cod_modulo
                            AND z.cod_modalidad = w.cod_modalidad
                            AND z.nro_cuenta = s.nro_cta_origen) --s.nro_cuenta )
                       /** Para que excluya los que no se envian a informconf. **/
                    AND p.cod_persona NOT IN (SELECT cod_persona
                                                FROM ba_per_dat_adicionales
                                               WHERE parametro LIKE 'ENV_INFORMCONF'
                                                 AND val_parametro = 'N')
                       /** No incluir en la Gestión de Cobranzas a los funcionarios. **/
                    AND NOT EXISTS (SELECT 1
                           FROM ba_usuarios u
                          WHERE u.cod_persona = l.cod_persona
                            AND nvl(u.estado, 'A') = 'A')
                       /** No incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
                    AND NOT EXISTS
                  (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
                 /** Agregado para CC_CTA_CORRIENTES que no pasaron a vencidas e ingresaron en el rango. **/
                 UNION ALL
                 SELECT DISTINCT p.cod_persona,
                                 x.nro_cuenta,
                                 substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'),
                                        1, 15) nro_documento,
                                 w.cod_modulo,
                                 substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                                 substr(f.seg_nombre, 1, 15) seg_nombre,
                                 substr(f.pri_apellido, 1, 20) pri_apellido,
                                 substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                                   pao_mor.fu_obt_ape_casada(f.cod_persona)),
                                            f.seg_apellido), 1, 20) seg_apellido,
                                 decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                        substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                                 (c_fec_actual - r.can_dia_sobregiro) fec_operacion,
                                 4 tip_operacion,
                                 0 nro_cuota,
                                 NULL can_cuotas,
                                 decode(nvl(w.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                                 0 mto_cuota,
                                 NULL fec_final,
                                 ' ' tip_actualizacion,
                                 'M' periodicidad,
                                 NULL pri_cuo_atrasada,
                                 1 can_cuo_atrasada,
                                 NULL pri_fec_ven_atrasada,
                                 NULL fec_ult_pago,
                                 r.mto_mora sal_mora,
                                 w.cod_modalidad,
                                 w.cod_moneda,
                                 'INC-1.6' observacion,
                                 r.can_dias dias_atraso,
                                 NULL nro_cta_nueva,
                                 4 cod_ori_modulo,
                                 41 cod_ori_modalidad,
                                 NULL cod_sec_credito
                   FROM cc_cta_corrientes x,
                        ge_cta_clientes   t,
                        ge_clientes       l,
                        ba_personas       p,
                        ba_per_fisicas    f,
                        ba_per_juridicas  j,
                        ge_cuentas        w,
                        ge_est_cuentas    e,
                        cc_sobregiros_res r
                  WHERE x.nro_cuenta = t.nro_cuenta
                    AND t.cod_persona = l.cod_persona
                    AND l.cod_persona = p.cod_persona
                    AND l.cod_persona = f.cod_persona(+)
                    AND l.cod_persona = j.cod_persona(+)
                    AND t.nro_cuenta = w.nro_cuenta
                    AND w.cod_modulo = e.cod_modulo
                    AND w.cod_modalidad = e.cod_modalidad
                    AND w.nro_cuenta = r.nro_cuenta(+)
                    AND nvl(t.relacion, 'x') = 'P'
                       --x AND ((x.dia_atraso >= nvl( v_dia_atr_ini_tar_informconf,0)   and l.cli_especial = 'N') OR
                       --x     (x.dia_atraso >= nvl( v_dia_atr_ini_sob_informconf,0) and l.cli_especial = 'S'))
                       --x AND x.dia_atraso >= v_dia_atr_ini_pre_informconf
                    AND x.estado = 'N'
                       --x AND nvl(x.mto_mora, 0) > nvl(v_sal_min_sob_cobranzas, 0)
                       --x AND nvl(x.mto_mora, 0) <= nvl(v_sal_max_sob_cobranzas, 0)
                    AND NOT EXISTS
                  (SELECT j.nro_cta_origen
                           FROM ov_cta_vencidas j
                          WHERE j.nro_cta_origen = x.nro_cuenta
                            AND j.cod_modalidad = 152)
                       /** No debe de enviar cuentas judicializadas. **/
                    --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
                    AND fu_ver_cli_judicial(l.cod_persona) = 'N'
                    AND e.activo = 'S'
                       /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
                       Debe ser nulo o Pertenecer a cualquier Banca. **/
                    AND l.cod_usu_oficial IN
                        (SELECT cod_usuario
                           FROM ba_usuarios
                          WHERE oficial = 'S'
                            AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                                cod_banca IS NULL))
                    AND NOT EXISTS (SELECT 1
                           FROM co_inf_cob_personas s
                          WHERE s.cod_persona = l.cod_persona
                            AND s.nro_cuenta = x.nro_cuenta
                            AND s.nro_cuota = 0)
                       /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
                    AND NOT EXISTS
                  (SELECT 1
                           FROM ge_tra_prohibidas z
                          WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                            AND z.cod_modulo = w.cod_modulo
                            AND z.cod_modalidad = w.cod_modalidad
                            AND z.nro_cuenta = x.nro_cuenta)
                       /** Para que excluya los que no se envian a informconf. **/
                    AND p.cod_persona NOT IN (SELECT cod_persona
                                                FROM ba_per_dat_adicionales
                                               WHERE parametro LIKE 'ENV_INFORMCONF'
                                                 AND val_parametro = 'N')
                       /** No incluir en la Gestión de Cobranzas a los funcionarios. **/
                    AND NOT EXISTS (SELECT 1
                           FROM ba_usuarios u
                          WHERE u.cod_persona = l.cod_persona
                            AND nvl(u.estado, 'A') = 'A')
                       /** No incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
                    AND NOT EXISTS
                  (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
                 --**************************************************************
                  ORDER BY 5, -- Primer Nombre/Razón Social
                           6, -- Segundo Nombre
                           7, -- Primer Apellido
                           8, -- segundo Apellido
                           2, -- Número de Cuenta
                           12 -- Número de Cuota
                 ) t
          WHERE EXISTS (SELECT 1
                   FROM ba_telefonos bt
                  WHERE bt.cod_persona = t.cod_persona
                    AND bt.tip_linea = 'B')
            AND EXISTS
          (SELECT 1 FROM co_cta_preventivas_tmp bt WHERE bt.nro_cuenta = t.nro_cuenta)
            AND EXISTS (SELECT 1
                   FROM ta_cta_tarjetas tc, cc_movimientos_his mh
                  WHERE tc.nro_cuenta = t.nro_cuenta
                    AND tc.nro_cuenta = mh.nro_cuenta
                    AND mh.cod_tra_padre = '303'
                    AND instr(',' || v_afinidad || ',', ',' || tc.afinidad || ',') > 0
                  GROUP BY mh.nro_cuenta
                 HAVING MAX(mh.fecha) <= SYSDATE - 60);

      CURSOR modificaciones IS
      /** Esta primera parte recupera las nuevas cuotas que entran en mora de cuentas que no sufrieron pagos y ya estaban incluidas. **/
         SELECT DISTINCT p.cod_persona,
                         c.nro_cuenta,
                         substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                         c.cod_modulo,
                         substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                         substr(f.seg_nombre, 1, 15) seg_nombre,
                         substr(f.pri_apellido, 1, 20) pri_apellido,
                         substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                           pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido),
                                1, 20) seg_apellido,
                         decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                         c.fec_inicio fec_operacion,
                         1 tip_operacion,
                         (SELECT MIN(pr.nro_cuota)
                            FROM pr_cuotas pr
                           WHERE pr.nro_cuenta = u.nro_cuenta
                             AND nvl(pr.nro_cuota, 0) > 0
                             AND nvl(pr.estado, 'x') <> 'N'
                             AND pr.fec_vencimiento <= c_fec_actual) nro_cuota,
                         c.can_cuotas,
                         decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                         (nvl(u.mto_capital, 0) + nvl(u.mto_interes, 0)) mto_cuota,
                         to_date(NULL, 'DD/MM/YYYY') fec_final,
                         'D' tip_actualizacion,
                         'M' periodicidad,
                         z.pri_cuo_atr pri_cuo_atrasada,
                         z.can_cuo_atr can_cuo_atrasada,
                         z.pri_fec_ven_atr pri_fec_ven_atrasada,
                         b.fec_ult_pago,
                         z.sal_cuo_mora sal_mora,
                         c.cod_modalidad,
                         c.cod_moneda,
                         NULL nro_tarjeta,
                         'MOD-1.1' observacion,
                         w.dia_atraso dias_atraso,
                         NULL nro_cta_nueva,
                         NULL cod_ori_modulo,
                         NULL cod_ori_modalidad,
                         c.cod_sec_credito
           FROM pr_cta_prestamos c,
                ge_cta_clientes t,
                ge_clientes l,
                ba_personas p,
                ba_per_fisicas f,
                ba_per_juridicas j,
                pr_cuotas u,
                ge_est_cuentas e,
                ge_par_dinamicos o,
                ge_cuentas w,
                (SELECT x.nro_cuenta nro_cta, MAX(x.fecha) fec_ult_pago
                   FROM co_inf_cob_personas q, pr_cobros x
                  WHERE x.fecha >= v_fec_ult_env
                    AND nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                        nvl(x.mto_int_documentado, 0) > 0
                    AND EXISTS
                  (SELECT 1 FROM co_inf_cob_personas q WHERE q.nro_cuenta = x.nro_cuenta)
                  GROUP BY x.nro_cuenta) b,
                (SELECT x.nro_cuenta nro_cta,
                        MIN(x.nro_cuota) pri_cuo_atr,
                        COUNT(*) can_cuo_atr,
                        MIN(x.fec_vencimiento) pri_fec_ven_atr,
                        SUM(nvl(x.sal_capital, 0) + nvl(x.sal_interes, 0) +
                            nvl(x.sal_int_documentado, 0)) sal_cuo_mora
                   FROM pr_cuotas x
                  WHERE x.nro_cuota <> 0
                    AND x.estado <> 'N'
                    AND x.fec_vencimiento <= c_fec_actual
                    AND EXISTS
                  (SELECT 1 FROM co_inf_cob_personas q WHERE q.nro_cuenta = x.nro_cuenta)
                  GROUP BY x.nro_cuenta) z
          WHERE c.nro_cuenta = t.nro_cuenta
            AND l.cod_persona = t.cod_persona
            AND t.nro_cuenta = w.nro_cuenta
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
            AND nvl(t.relacion, 'x') = 'P'
            AND ((nvl(c.dia_atraso, 0) >= nvl(v_dia_atr_ini_pre_informconf, 0) AND
                l.cli_especial = 'N') OR
                (nvl(c.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                l.cli_especial = 'S'))
            AND l.cod_persona = p.cod_persona
            AND l.cod_persona = f.cod_persona(+)
            AND l.cod_persona = j.cod_persona(+)
            AND c.nro_cuenta = u.nro_cuenta
            AND nvl(u.nro_cuota, 0) > 0
            AND nvl(u.estado, 'x') <> 'N'
            AND u.fec_vencimiento <= c_fec_actual
            AND c.nro_cuenta = b.nro_cta(+)
            AND c.nro_cuenta = z.nro_cta
            AND nvl(z.sal_cuo_mora, 0) > v_sal_min_pre_cobranzas
            AND nvl(z.sal_cuo_mora, 0) <= v_sal_max_pre_cobranzas
            AND c.cod_modulo = e.cod_modulo
            AND c.cod_modalidad = e.cod_modalidad
            AND c.estado = e.estado
            AND e.activo = 'S'
            AND c.estado <> 'I'
            --AND nvl(c.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
               /** Por módulo y modalidad solo los que el par. dinámico= 'S'. **/
            AND o.parametro = 'MOD_COBRANZAS'
            AND nvl(o.val_parametro, 'N') = 'S'
            AND o.cod_modulo = c.cod_modulo
            AND o.cod_modalidad = c.cod_modalidad
               /** Para bancas(Join ge_clientes, ba_usuarios para cod_banca). **/
            AND l.cod_usu_oficial IN
                (SELECT cod_usuario
                   FROM ba_usuarios
                  WHERE oficial = 'S'
                       /** Debe ser nulo o Pertenecer a cualquier Banca, si se desea enviar mas
                       bancas en un futuro se debe de incluir en el par_dinamico(TIP_BAN_INFORMCONF) ej.(1,2,3,...etc.) para el IN. **/
                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                        cod_banca IS NULL))
               --*******************************************************
               /** Si existe en informado quiere decir que se envió ya a informconf. **/
            AND EXISTS (SELECT 1 --- Que exista informado
                   FROM co_inf_cob_personas x
                  WHERE x.cod_persona = l.cod_persona
                    AND x.nro_cuenta = c.nro_cuenta)
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS (SELECT 1
                   FROM ge_tra_prohibidas z
                  WHERE z.cod_transaccion IN (nvl(v_cod_tra_prohibida, '0')) -- No enviar a Cobranzas
                    AND z.cod_modulo = c.cod_modulo
                    AND z.cod_modalidad = c.cod_modalidad
                    AND z.nro_cuenta = c.nro_cuenta)
               /** o no es 5-CASH COLLATERAL. **/
            AND NOT EXISTS (SELECT 1
                   FROM pr_cta_garantias x
                  WHERE x.nro_cuenta = c.nro_cuenta
                    AND x.cod_garantia = 5)
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = l.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
            AND NOT EXISTS
          (SELECT 1 /** Que esta cuota no se haya informado aun. **/
                   FROM co_inf_cob_personas x
                  WHERE x.cod_persona = l.cod_persona
                    AND x.nro_cuenta = c.nro_cuenta
                    AND x.nro_cuota = (SELECT MIN(pr.nro_cuota)
                                         FROM pr_cuotas pr
                                        WHERE pr.nro_cuenta = u.nro_cuenta
                                          AND nvl(pr.nro_cuota, 0) > 0
                                          AND nvl(pr.estado, 'x') <> 'N'
                                          AND pr.fec_vencimiento <= c_fec_actual))
            AND EXISTS (SELECT MAX(x.fec_ult_pago), MAX(q.fecha)
                   FROM co_inf_cob_personas x, pr_cobros q
                  WHERE x.cod_persona = l.cod_persona
                    AND x.nro_cuenta = c.nro_cuenta
                    AND x.nro_cuenta = q.nro_cuenta
                    AND x.nro_cuota = q.nro_cuota
                    AND nvl(q.mto_capital, 0) + nvl(q.mto_interes, 0) +
                        nvl(q.mto_int_documentado, 0) > 0
                  HAVING(MAX(x.fec_ult_pago) IS NULL
                            OR MAX(x.fec_ult_pago) = MAX(q.fecha)))
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
         UNION ALL
         SELECT p.cod_persona,
                c.nro_cuenta,
                substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15) nro_documento,
                c.cod_modulo,
                substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65) pri_nombre,
                substr(f.seg_nombre, 1, 15) seg_nombre,
                substr(f.pri_apellido, 1, 20) pri_apellido,
                substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                  pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido), 1, 20) seg_apellido,
                decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                       substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)) ape_casada,
                c.fec_apertura fec_operacion,
                3 tip_operacion,
                0 nro_cuota,
                NULL can_cuotas,
                decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D') tip_moneda,
                decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1, nvl(c.mto_mora, 0),
                       /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                       nvl(c.mto_mora, 0),
                       /** Si el pago mínimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                       nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)) mto_cuota,
                to_date(NULL, 'DD/MM/YYYY') fec_final,
                'D' tip_actualizacion,
                'M' periodicidad,
                NULL pri_cuo_atrasada,
                1 can_cuo_atrasada,
                (c_fec_actual - nvl(c.dia_mora, 0)) pri_fec_ven_atrasada,
                MAX(b.fec_proceso) fec_ult_pago,
                decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1, nvl(c.mto_mora, 0),
                       /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                       nvl(c.mto_mora, 0),
                       /** Si el pago mínimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                       nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)) sal_mora,
                c.cod_modalidad,
                c.cod_moneda,
                NULL nro_tarjeta,
                'MOD-1.2' observacion,
                w.dia_atraso dias_atraso,
                NULL nro_cta_nueva,
                NULL cod_ori_modulo,
                NULL cod_ori_modalidad,
                NULL cod_sec_credito
           FROM ta_cta_tarjetas  c,
                ge_cta_clientes  t,
                ge_clientes      l,
                ba_personas      p,
                ba_per_fisicas   f,
                ba_per_juridicas j,
                ta_cobros        b,
                ge_est_cuentas   e,
                ge_par_dinamicos o,
                ge_cuentas       w
          WHERE c.nro_cuenta = t.nro_cuenta
            AND l.cod_persona = t.cod_persona
            AND nvl(t.relacion, 'x') = 'P'
            AND ((nvl(c.dia_mora, 0) >= nvl(v_dia_atr_ini_tar_informconf, 0) AND
                l.cli_especial = 'N') OR
                (nvl(c.dia_mora, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                l.cli_especial = 'S'))
            AND nvl(c.mto_mora, 0) > v_sal_min_tar_cob_informconf
            AND nvl(c.mto_mora, 0) <= v_sal_max_tar_cobranzas
            AND l.cod_persona = p.cod_persona
            AND l.cod_persona = f.cod_persona(+)
            AND l.cod_persona = j.cod_persona(+)
            AND c.nro_cuenta = b.nro_cuenta(+)
            AND nvl(b.fec_proceso(+), c_fec_actual) >= v_fec_ult_env
            AND nvl(b.fec_proceso(+), c_fec_actual) <
                decode(b.fec_proceso(+), NULL, c_fec_actual + 1, c_fec_actual)
            AND c.cod_modulo = e.cod_modulo
            AND c.cod_modalidad = e.cod_modalidad
            AND c.estado = e.estado
            AND t.nro_cuenta = w.nro_cuenta
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(w.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(l.cod_persona) = 'N'
            AND e.activo = 'S'
            AND c.estado <> 'I'
            --AND nvl(c.en_juicio, 'N') = 'N' V.O. 17-10-13
               /** Para bancas (Join ge_clientes, ba_usuarios para cod_banca)
               Debe ser nulo o Pertenecer a cualquier Banca, si se desea enviar mas
               bancas en un futuro se debe de incluir en el par_dinamico(TIP_BAN_INFORMCONF) ej.(1,2,3,...etc.) para el IN. **/
            AND l.cod_usu_oficial IN
                (SELECT cod_usuario
                   FROM ba_usuarios
                  WHERE oficial = 'S'
                    AND (instr(',' || v_tip_banca || ',', ',' || to_char(cod_banca) || ',') > 0 OR
                        cod_banca IS NULL))
               /** Por módulo y modalidad solo los que el par. dinámico = 'S'. **/
            AND o.parametro = 'MOD_COBRANZAS'
            AND nvl(o.val_parametro, 'N') = 'S'
            AND o.cod_modulo = c.cod_modulo
            AND o.cod_modalidad = c.cod_modalidad
               --***********************************************************
            AND (EXISTS (SELECT 1
                           FROM co_inf_cob_personas x
                          WHERE x.cod_persona = l.cod_persona
                            AND x.nro_cuenta = c.nro_cuenta
                            AND x.nro_cuota = 0
                            AND nvl(x.mto_deuda, 0) <>
                                decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1,
                                       nvl(c.mto_mora, 0),
                                       /** Si el monto en mora es mayor, entonces se informa este. **/
                                       0, nvl(c.mto_mora, 0),
                                       /** Si el pago mínimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                                       nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0))) /** aqui está Modificando el monto informado de las tarjetas (nuevo extracto en mora). **/
                )
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS (SELECT 1
                   FROM ge_tra_prohibidas z
                  WHERE z.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND z.cod_modulo = c.cod_modulo
                    AND z.cod_modalidad = c.cod_modalidad
                    AND z.nro_cuenta = c.nro_cuenta)
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = l.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = t.nro_cuenta)
          GROUP BY p.cod_persona,
                   c.nro_cuenta,
                   substr(fuo_set_documento(p.cod_tip_documento, p.nro_documento, 'N'), 1, 15),
                   c.cod_modulo,
                   substr(decode(f.pri_nombre, NULL, j.raz_social, f.pri_nombre), 1, 65),
                   substr(f.seg_nombre, 1, 15),
                   substr(f.pri_apellido, 1, 20),
                   substr(nvl(decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                                     pao_mor.fu_obt_ape_casada(f.cod_persona)), f.seg_apellido), 1,
                          20),
                   decode(nvl(f.cod_sexo, 'M'), 'M', NULL,
                          substr(pao_mor.fu_obt_ape_casada(f.cod_persona), 1, 20)),
                   c.fec_apertura,
                   3,
                   0,
                   NULL,
                   decode(nvl(c.cod_moneda, 'GS'), 'GS', 'G', 'USD', 'D'),
                   nvl(c.mto_pag_minimo, 0),
                   to_date(NULL, 'DD/MM/YYYY'),
                   ' ',
                   'M',
                   NULL,
                   NULL,
                   (c_fec_actual - nvl(c.dia_mora, 0)),
                   decode(sign(nvl(c.mto_mora, 0) - nvl(c.mto_pag_minimo, 0)), 1, nvl(c.mto_mora, 0),
                          /** Si el monto en mora es mayor, entonces se informa este. **/ 0,
                          nvl(c.mto_mora, 0),
                          /** Si el pago mínimo es mayor, se informa el pago minimo-pagos del mes (lo que necesita pagar para salir de mora). **/
                          nvl(c.mto_pag_minimo, 0) - nvl(c.mto_pag_mes, 0)),
                   c.cod_modalidad,
                   c.cod_moneda,
                   w.dia_atraso
         UNION ALL
         /** ENVIO DE PAGOS.**/
         SELECT o.cod_persona,
                o.nro_cuenta,
                o.nro_documento,
                o.cod_modulo,
                o.pri_nombre,
                o.seg_nombre,
                o.pri_apellido,
                o.seg_apellido,
                o.ape_casada,
                o.fec_operacion,
                to_number(o.tip_inf_operacion),
                o.nro_cuota,
                o.can_cuotas,
                o.tip_inf_moneda,
                o.mto_cuota,
                o.fec_final,
                'P' tip_inf_actualizacion,
                o.inf_periodicidad,
                o.pri_cuo_atrasada,
                o.can_cuo_atrasada,
                o.fec_vencimiento pri_fec_ven_atrasada,
                b.fec_ult_pago,
                o.mto_deuda sal_mora,
                o.cod_modalidad,
                o.cod_moneda,
                o.nro_tarjeta,
                'MOD-1.3' observacion,
                decode(nvl(g.dia_atraso, 0), 0, 1, g.dia_atraso) dias_atraso,
                NULL nro_cta_nueva,
                NULL cod_ori_modulo,
                NULL cod_ori_modalidad,
                o.cod_sec_credito
           FROM co_inf_cob_personas o,
                ge_cuentas g,
                (SELECT x.nro_cuenta nro_cta, x.nro_cuota nro_cuo, MAX(x.fecha) fec_ult_pago
                   FROM co_inf_cob_personas q, pr_cobros x
                  WHERE q.nro_cuenta = x.nro_cuenta
                    AND q.nro_cuota = x.nro_cuota
                    AND nvl(x.mto_capital, 0) + nvl(x.mto_interes, 0) +
                        nvl(x.mto_int_documentado, 0) > 0
                    AND x.fecha >= v_fec_ult_env
                  GROUP BY x.nro_cuenta, x.nro_cuota) b
          WHERE o.nro_cuenta = g.nro_cuenta
            AND g.estado <> 'I'
            --AND nvl(g.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(o.cod_persona) = 'N'
            AND o.nro_cuenta = b.nro_cta
            AND o.nro_cuota = b.nro_cuo
            AND (nvl(o.fec_ult_pago, trunc(SYSDATE) - 360) < b.fec_ult_pago OR NOT EXISTS
                 (SELECT 1
                    FROM ge_cuentas x, ge_cta_clientes y, ge_clientes z
                   WHERE x.nro_cuenta = o.nro_cuenta
                     AND x.cod_modulo = o.cod_modulo
                     AND x.nro_cuenta = y.nro_cuenta
                     AND z.cod_persona = y.cod_persona
                     AND y.relacion IN ('P')
                     AND ((nvl(x.dia_atraso, 0) >= nvl(v_dia_atr_ini_pre_informconf, 0) AND
                         z.cli_especial = 'N') OR
                         (nvl(x.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                         z.cli_especial = 'S'))))
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS (SELECT 1
                   FROM ge_tra_prohibidas h
                  WHERE h.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND h.cod_modulo = o.cod_modulo
                    AND h.cod_modalidad = o.cod_modalidad
                    AND h.nro_cuenta = o.nro_cuenta)
               /** No enviar como cobradas operaciones RRR. **/
            AND NOT EXISTS (SELECT 1
                   FROM pr_cta_prestamos p
                  WHERE p.nro_cuenta = o.nro_cuenta
                    AND p.estado = 'N'
                    AND p.nro_cta_renovada IS NOT NULL)
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         UNION ALL
         SELECT o.cod_persona,
                o.nro_cuenta,
                o.nro_documento,
                o.cod_modulo,
                o.pri_nombre,
                o.seg_nombre,
                o.pri_apellido,
                o.seg_apellido,
                o.ape_casada,
                o.fec_operacion,
                to_number(o.tip_inf_operacion),
                o.nro_cuota,
                o.can_cuotas,
                o.tip_inf_moneda,
                o.mto_cuota,
                o.fec_final,
                'P' tip_inf_actualizacion,
                o.inf_periodicidad,
                o.pri_cuo_atrasada,
                o.can_cuo_atrasada,
                o.fec_vencimiento pri_fec_ven_atrasada,
                b.fec_ult_pago,
                o.mto_deuda sal_mora,
                o.cod_modalidad,
                o.cod_moneda,
                o.nro_tarjeta,
                'MOD-1.4' observacion,
                nvl(g.dia_atraso, 0) dias_atraso,
                NULL nro_cta_nueva,
                NULL cod_ori_modulo,
                NULL cod_ori_modalidad,
                o.cod_sec_credito
           FROM co_inf_cob_personas o,
                ge_cuentas g,
                (SELECT x.nro_cuenta nro_cta, MAX(x.fec_proceso) fec_ult_pago
                   FROM co_inf_cob_personas q, ta_cobros x
                  WHERE q.nro_cuenta = x.nro_cuenta
                    AND x.fec_proceso >= v_fec_ult_env
                    AND x.fec_proceso < c_fec_actual
                       /** Para que no se remita como cobradas las tarjetas con saldo insuficiente. **/
                    AND x.estado = 'P'
                  GROUP BY x.nro_cuenta) b
          WHERE o.nro_cuenta = g.nro_cuenta
            AND g.estado <> 'I'
            --AND nvl(g.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(o.cod_persona) = 'N'
            AND o.nro_cuenta = b.nro_cta
            AND (nvl(o.fec_ult_pago, trunc(SYSDATE) - 360) < b.fec_ult_pago OR NOT EXISTS
                 (SELECT 1
                    FROM ge_cuentas x, ge_cta_clientes y, ge_clientes z
                   WHERE x.nro_cuenta = o.nro_cuenta
                     AND x.cod_modulo = o.cod_modulo
                     AND x.nro_cuenta = y.nro_cuenta
                     AND z.cod_persona = y.cod_persona
                     AND y.relacion = 'P'
                     AND ((nvl(x.dia_atraso, 0) >=
                         decode(x.cod_modulo, 5, nvl(v_dia_atr_ini_tar_informconf, 0), 6,
                                  nvl(v_dia_atr_ini_pre_informconf, 0)) AND z.cli_especial = 'N') OR
                         (nvl(x.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                         z.cli_especial = 'S'))

                     AND nvl(x.mto_mora, 0) > v_sal_min_tar_cob_informconf))
               /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
            AND NOT EXISTS (SELECT 1
                   FROM ge_tra_prohibidas h
                  WHERE h.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                    AND h.cod_modulo = o.cod_modulo
                    AND h.cod_modalidad = o.cod_modalidad
                    AND h.nro_cuenta = o.nro_cuenta)
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)

         /** ENVIO DE PAGO DE SOBREGIRO.**/
         UNION ALL
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'P' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.4' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         o.nro_cta_nueva,
                         o.cod_ori_modulo,
                         o.cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o
          WHERE o.tip_inf_operacion = 4
            AND EXISTS (SELECT 1
                   FROM ov_cobros w
                  WHERE w.nro_cuenta = o.nro_cta_nueva --o.nro_cuenta
                    AND trunc(w.fecha) = trunc(c_fec_actual))
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         /** Envio de Pagos de Tarjetas Vencidas.**/
         UNION ALL
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'P' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.5' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         o.nro_cta_nueva,
                         o.cod_ori_modulo,
                         o.cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o
          WHERE o.tip_inf_operacion = 3
            AND o.cod_modulo = 5
            AND EXISTS (SELECT 1
                   FROM ov_cobros w
                  WHERE w.nro_cuenta = o.nro_cta_nueva --o.nro_cuenta
                    AND trunc(w.fecha) = trunc(c_fec_actual))
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         /** Envio de Pagos de CC_CTA_VENCIDAS.**/
         UNION ALL
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'P' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.6' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         NULL nro_cta_nueva,
                         4 cod_ori_modulo,
                         41 cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o, cc_cta_corrientes w, cc_sobregiros_res r
          WHERE o.tip_inf_operacion = 4
            AND o.nro_cuenta = w.nro_cuenta
            AND w.nro_cuenta = r.nro_cuenta(+)
            AND w.estado <> 'C'
            AND o.mto_cuota > r.mto_mora
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         UNION ALL
         /** Envio los que el proceso de Cierre de Mes hizo que aumentaran su deuda (Mto_Mora), se informa como incremento. **/
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'D' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.7' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         NULL nro_cta_nueva,
                         4 cod_ori_modulo,
                         41 cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o, cc_cta_corrientes w, cc_sobregiros_res r
          WHERE o.tip_inf_operacion = 4
            AND o.nro_cuenta = w.nro_cuenta
            AND w.nro_cuenta = r.nro_cuenta(+)
            AND w.estado <> 'C'
            AND o.mto_cuota < r.mto_mora
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
         UNION ALL
         /** Envio los que ya fueron enviadas como tarjetas o cc_cta_corrientes y aumentaron su deuda al pasar a vencidas. **/
         SELECT DISTINCT o.cod_persona,
                         o.nro_cuenta,
                         o.nro_documento,
                         o.cod_modulo,
                         o.pri_nombre,
                         o.seg_nombre,
                         o.pri_apellido,
                         o.seg_apellido,
                         o.ape_casada,
                         o.fec_operacion,
                         to_number(o.tip_inf_operacion) tip_inf_operacion,
                         o.nro_cuota,
                         o.can_cuotas,
                         o.tip_inf_moneda,
                         o.mto_cuota,
                         o.fec_final,
                         'D' tip_inf_actualizacion,
                         o.inf_periodicidad,
                         o.pri_cuo_atrasada,
                         o.can_cuo_atrasada,
                         o.fec_vencimiento pri_fec_ven_atrasada,
                         c_fec_actual fec_ult_pago,
                         o.mto_deuda sal_mora,
                         o.cod_modalidad,
                         o.cod_moneda,
                         o.nro_tarjeta,
                         'MOD-1.9' observacion,
                         (SELECT p.dia_atraso
                            FROM co_inf_cob_diarios p
                           WHERE p.nro_cuenta = o.nro_cuenta
                             AND p.cod_modulo = o.cod_modulo
                             AND rownum = 1) dias_atraso,
                         w.nro_cuenta nro_cta_nueva,
                         o.cod_ori_modulo,
                         o.cod_ori_modalidad,
                         o.cod_sec_credito
           FROM co_inf_cob_personas o, ov_cta_vencidas w
          WHERE o.tip_inf_operacion IN (3, 4)
            AND o.nro_cuenta = w.nro_cta_origen
            AND nvl(o.mto_cuota, 0) < nvl(w.sal_total, 0)
            AND w.estado <> 'C'
               /** Para no incluir en la Gestión de Cobranzas a los funcionarios. **/
            AND NOT EXISTS (SELECT 1
                   FROM ba_usuarios u
                  WHERE u.cod_persona = o.cod_persona
                    AND nvl(u.estado, 'A') = 'A')
               /** Para no incluir en la Gestión de Cobranzas las Ventas de Cartera. **/
            AND NOT EXISTS (SELECT 1 FROM pr_vta_cartera p WHERE p.nro_cuenta = o.nro_cuenta)
          ORDER BY 5, -- Primer Nombre/Razón Social
                   6, -- Segundo Nombre
                   7, -- Primer Apellido
                   8, -- segundo Apellido
                   2, -- Número de Cuenta
                   12; -- Número de Cuota

      CURSOR exclusiones IS
         SELECT o.cod_persona,
                o.nro_cuenta,
                o.nro_cuota,
                o.nro_documento,
                o.pri_nombre,
                o.seg_nombre,
                o.pri_apellido,
                o.seg_apellido,
                o.ape_casada,
                o.dir_particular,
                o.dir_laboral,
                o.dir_lab_alternativo,
                o.tel_particular,
                o.tel_laboral,
                o.tel_lab_alternativo,
                o.fec_operacion,
                o.can_cuotas,
                o.tip_inf_operacion,
                o.pri_cuo_atrasada,
                o.can_cuo_atrasada,
                o.mto_cuota,
                o.fec_vencimiento,
                o.fec_ult_pago,
                o.nro_tarjeta,
                o.tip_inf_garantia,
                o.tip_inf_moneda,
                o.mto_deuda,
                o.fec_final,
                o.tip_inf_cobro,
                o.mto_cobrado,
                o.fec_cobro,
                o.tip_inf_actualizacion,
                o.inf_periodicidad,
                o.cod_modulo,
                o.cod_modalidad,
                o.cod_moneda,
                'Exc-1' observacion,
                o.cod_sec_credito
           FROM co_inf_cob_personas o,
                ba_per_fisicas      f,
                ba_per_juridicas    j,
                ge_cuentas          g,
                ge_par_dinamicos    d,
                ge_est_cuentas      e
          WHERE (NOT EXISTS (SELECT 1 FROM ge_cuentas c WHERE c.nro_cuenta = o.nro_cuenta) OR
                /** Esta parte es que no envíe las cuentas con transacciones prohibídas. **/
                 EXISTS (SELECT 1
                           FROM ge_tra_prohibidas h
                          WHERE h.cod_transaccion IN (v_cod_tra_prohibida) -- No enviar a Cobranzas
                            AND h.cod_modulo = o.cod_modulo
                            AND h.cod_modalidad = o.cod_modalidad
                            AND h.nro_cuenta = o.nro_cuenta) OR NOT EXISTS
                 (SELECT 1 /** Se agregó para que elimine las cuentas que no tengan dias de mora ni monto en mora. **/
                    FROM ge_cuentas x, ge_cta_clientes y, ge_clientes z
                   WHERE x.nro_cuenta = o.nro_cuenta
                     AND x.cod_modulo = o.cod_modulo
                     AND x.nro_cuenta = y.nro_cuenta
                     AND z.cod_persona = y.cod_persona
                     AND y.relacion IN ('P')
                     AND ((nvl(x.dia_atraso, 0) >=
                         decode(x.cod_modulo, 5, nvl(v_dia_atr_ini_tar_informconf, 0), 6,
                                  nvl(v_dia_atr_ini_pre_informconf, 0)) AND z.cli_especial = 'N') OR
                         (nvl(x.dia_atraso, 0) >= nvl(v_dia_atr_vip_cob_tercerizadas, 0) AND
                         z.cli_especial = 'S'))
                        /** Excluye las TARJETAS con montos inferiores al parametro. **/
                     AND (x.cod_modulo <> 5 OR
                         nvl(x.mto_mora, 0) > nvl(v_sal_min_tar_cob_informconf, 0))) OR
                --o es 5-CASH COLLATERAL
                 EXISTS (SELECT 1
                           FROM pr_cta_garantias x
                          WHERE x.nro_cuenta = o.nro_cuenta
                            AND x.cod_garantia = 5) OR EXISTS
                 (SELECT 1
                    FROM ba_usuarios u
                   WHERE u.cod_persona = o.cod_persona
                     AND nvl(u.estado, 'A') <> 'I') OR e.activo <> 'S' OR g.estado = 'I' OR
                 /*nvl(g.en_juicio, 'N') = 'S'*/
                  fu_ver_cli_judicial(o.cod_persona) = 'N' OR nvl(d.val_parametro, 'N') = 'N')
            AND o.cod_persona = f.cod_persona(+)
            AND o.cod_persona = j.cod_persona(+)
               /** No debe de enviar cuentas judicializadas. **/
            --AND nvl(g.en_juicio, 'N') <> 'S' V.O. 17-10-13
            AND fu_ver_cli_judicial(o.cod_persona) = 'N'
               /** Por módulo y modalidad solo los que el par.dinámico='S'. **/
            AND d.parametro = 'MOD_COBRANZAS'
            AND d.cod_modulo = o.cod_modulo
            AND d.cod_modalidad = o.cod_modalidad
               --**************************************
            AND o.nro_cuenta = g.nro_cuenta
            AND e.cod_modulo = g.cod_modulo
            AND e.cod_modalidad = g.cod_modalidad
            AND e.estado = g.estado
               /** Que no incluya las tarjetas vencidas. **/
            AND (((o.cod_modulo = 5 AND o.observacion <> 'INC-1.4') AND NOT EXISTS
                 (SELECT 1
                     FROM ta_cobros j
                    WHERE j.nro_cuenta = o.nro_cuenta
                      AND j.fec_proceso >= v_fec_ult_env
                      AND j.fec_proceso < c_fec_actual)) OR
                (o.cod_modulo = 6 AND NOT EXISTS
                 (SELECT 1
                     FROM pr_cobros k
                    WHERE k.nro_cuenta = o.nro_cuenta
                      AND k.fecha >= v_fec_ult_env
                      AND nvl(k.mto_capital, 0) + nvl(k.mto_interes, 0) +
                          nvl(k.mto_int_documentado, 0) > 0)))
          ORDER BY decode(f.pri_apellido, NULL, j.raz_social, f.pri_nombre),
                   f.seg_apellido,
                   f.pri_nombre,
                   f.seg_nombre;

      FUNCTION lf_obt_garantia
      (
         p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
         p_cod_modulo  ge_cuentas.cod_modulo%TYPE,
         p_observacion VARCHAR2
      ) RETURN NUMBER IS
         v_cod NUMBER(3);
      BEGIN
         IF p_cod_modulo = 5 AND p_observacion IN ('INC-1.2', 'MOD-1.2') THEN
            /** Si es tarjeta Normal. **/
            BEGIN
               SELECT cod_garantia
                 INTO v_cod
                 FROM ta_cta_garantias
                WHERE nro_cuenta = p_nro_cuenta
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cod := NULL;
            END;
         ELSIF p_cod_modulo = 5 AND p_observacion NOT IN ('INC-1.2', 'MOD-1.2') THEN
            /** Si es tarjeta Vencida. **/
            BEGIN
               SELECT c.cod_garantia
                 INTO v_cod
                 FROM ov_cta_vencidas a, ta_cta_tarjetas b, ta_cta_garantias c
                WHERE a.nro_cta_origen = b.nro_cuenta
                  AND b.nro_cuenta = c.nro_cuenta
                  AND a.nro_cuenta = p_nro_cuenta
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cod := NULL;
            END;
         ELSIF p_cod_modulo = 6 THEN
            /** Si es préstamo. **/
            BEGIN
               SELECT cod_garantia
                 INTO v_cod
                 FROM pr_cta_garantias
                WHERE nro_cuenta = p_nro_cuenta
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_cod := NULL;
            END;
            /** Se busca la garantia en sobregiros o cta_cte. **/
         ELSIF p_cod_modulo = 4 THEN
            /** Si es sobregiro o cta_cte se asume a sola firma. **/
            v_cod := 1;
         END IF;
         RETURN v_cod;
      END lf_obt_garantia;

      /** Procedimiento donde se obtiene el Pago Realizado. **/
      PROCEDURE lp_obt_pago
      (
         p_nro_cuenta   IN ge_cuentas.nro_cuenta%TYPE,
         p_nro_cuota    IN pr_cuotas.nro_cuota%TYPE,
         p_cod_modulo   IN ge_cuentas.cod_modulo%TYPE,
         p_tip_cobro    OUT VARCHAR2,
         p_fec_ult_pago OUT DATE,
         p_mto_ult_pago OUT NUMBER,
         p_tip_informe  IN VARCHAR2,
         p_can_cuotas   pr_cuotas.nro_cuota%TYPE
      ) IS
         v_old_fec_cobro DATE;
         v_new_fec_cobro DATE;
         v_new_mto_cobro NUMBER(18, 2);
         v_new_mto_cuota NUMBER(18, 2);
      BEGIN
         BEGIN
            SELECT nvl(fec_cobro, fec_ini_envio
                       /*decode(fec_ini_envio, to_date('01/01/2010', 'DD/MM/YYYY'), trunc(SYSDATE) - 3,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        fec_ini_envio)*/)
              INTO v_old_fec_cobro
              FROM co_inf_cob_personas
             WHERE nro_cuenta = p_nro_cuenta
               AND nro_cuota = p_nro_cuota;
         EXCEPTION
            WHEN OTHERS THEN
               v_old_fec_cobro := to_date('01/01/1900', 'DD/MM/YYYY');
         END;
         /** Si es tarjeta. **/
         IF p_cod_modulo = 5 THEN
            BEGIN
               SELECT MAX(c.fec_proceso), SUM(c.monto)
                 INTO v_new_fec_cobro, v_new_mto_cobro
                 FROM ta_cobros c
                WHERE c.nro_cuenta = p_nro_cuenta
                  AND c.fec_proceso >= v_old_fec_cobro
                  AND c.fec_proceso < c_fec_actual;
            EXCEPTION
               WHEN OTHERS THEN
                  v_new_fec_cobro := NULL;
                  v_new_mto_cobro := NULL;
            END;
            IF v_old_fec_cobro <> nvl(v_new_fec_cobro, v_old_fec_cobro) OR
               nvl(p_tip_informe, 'x') = 'P' THEN
               BEGIN
                  SELECT mto_deuda
                    INTO v_new_mto_cuota
                    FROM co_inf_cob_personas
                   WHERE nro_cuenta = p_nro_cuenta
                     AND nro_cuota = 0;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_new_mto_cuota := NULL;
               END;
               IF nvl(v_new_mto_cobro, 0) > nvl(v_new_mto_cuota, 0) THEN
                  v_new_mto_cobro := nvl(v_new_mto_cuota, 0);
               END IF;
            END IF;
            /** Si es Préstamo. **/
         ELSIF p_cod_modulo = 6 THEN
            IF nvl(p_tip_informe, 'x') = 'P' /*AND
                                                                                                                                                                                                                                    v_old_fec_cobro IN
                                                                                                                                                                                                                                    (to_date('25/05/2006', 'dd/mm/yyyy'), to_date('26/05/2006', 'dd/mm/yyyy'))*/
             THEN
               BEGIN
                  SELECT MAX(c.fecha),
                         SUM(nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) +
                             nvl(c.mto_int_documentado, 0))
                    INTO v_new_fec_cobro, v_new_mto_cobro
                    FROM pr_cobros c
                   WHERE c.nro_cuenta = p_nro_cuenta
                     AND nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) +
                         nvl(c.mto_int_documentado, 0) > 0
                     AND c.fecha >= v_old_fec_cobro;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_new_fec_cobro := NULL;
                     v_new_mto_cobro := NULL;
               END;
            ELSE
               BEGIN
                  SELECT MAX(c.fecha),
                         SUM(nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) +
                             nvl(c.mto_int_documentado, 0))
                    INTO v_new_fec_cobro, v_new_mto_cobro
                    FROM pr_cobros c
                   WHERE c.nro_cuenta = p_nro_cuenta
                     AND c.nro_cuota >= p_nro_cuota
                     AND c.nro_cuota <= (nvl(p_nro_cuota, 0) + nvl(p_can_cuotas, 0) - 1)
                     AND c.fecha >= v_old_fec_cobro
                     AND nvl(c.mto_capital, 0) + nvl(c.mto_interes, 0) +
                         nvl(c.mto_int_documentado, 0) > 0;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_new_fec_cobro := NULL;
                     v_new_mto_cobro := NULL;
               END;
            END IF;
            IF v_old_fec_cobro <> nvl(v_new_fec_cobro, v_old_fec_cobro) OR
               nvl(p_tip_informe, 'x') = 'P' THEN
               BEGIN
                  SELECT mto_deuda
                    INTO v_new_mto_cuota
                    FROM co_inf_cob_personas
                   WHERE nro_cuenta = p_nro_cuenta
                     AND nro_cuota = p_nro_cuota;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_new_mto_cuota := NULL;
               END;

               IF nvl(v_new_mto_cobro, 0) > nvl(v_new_mto_cuota, 0) THEN
                  v_new_mto_cobro := nvl(v_new_mto_cuota, 0);
               END IF;
            END IF;
         END IF;
         IF nvl(v_new_mto_cobro, 0) <> 0 THEN
            IF nvl(v_new_mto_cobro, 0) = nvl(v_new_mto_cuota, 0) THEN
               p_tip_cobro := 'T';
            ELSE
               p_tip_cobro := 'P';
            END IF;
         ELSE
            p_tip_cobro := NULL;
         END IF;
         p_fec_ult_pago := v_new_fec_cobro;
         p_mto_ult_pago := v_new_mto_cobro;
      END lp_obt_pago;

      /** Obtiene el Nro de Tarjeta del Cliente. **/
      FUNCTION lf_obt_tarjeta
      (
         p_nro_cuenta  IN ta_cta_tarjetas.nro_cuenta%TYPE,
         p_observacion VARCHAR2,
         p_mensaje     OUT VARCHAR2
      ) RETURN VARCHAR2 IS
         v_nro_tarjeta ta_tarjetas.nro_tarjeta%TYPE;
      BEGIN
         BEGIN
            SELECT t.nro_tarjeta
              INTO v_nro_tarjeta
              FROM ta_tarjetas t, ge_cta_clientes c
             WHERE t.nro_cuenta = p_nro_cuenta
               AND t.nro_cuenta = c.nro_cuenta
               AND t.cod_persona = c.cod_persona
               AND nvl(c.relacion, 'x') = 'P'
               AND nvl(t.vigente, 'N') = 'S'
               AND rownum = 1;
         EXCEPTION
            WHEN no_data_found THEN
               BEGIN
                  /** Buscamos en tarjetas Vencidas. **/
                  SELECT t.nro_tarjeta
                    INTO v_nro_tarjeta
                    FROM ov_cta_vencidas a, ta_tarjetas t, ge_cta_clientes c
                   WHERE a.nro_cta_origen = t.nro_cuenta
                     AND t.nro_cuenta = c.nro_cuenta
                     AND t.cod_persona = c.cod_persona
                     AND a.nro_cuenta = p_nro_cuenta
                     AND nvl(c.relacion, 'x') = 'P'
                        --and nvl( t.vigente, 'N' ) = 'S'
                     AND rownum = 1;
                  --v_nro_tarjeta := NULL;
               EXCEPTION
                  /** Sino encuentra enviamos nro_cuenta(En el campo se puede enviar uno los dos datos a Informconf). **/
                  WHEN no_data_found THEN
                     v_nro_tarjeta := p_nro_cuenta;
               END;
            WHEN OTHERS THEN
               p_mensaje := 'Error al buscar la tarjeta para la cuenta ' || p_nro_cuenta || '; ' ||
                            SQLERRM;
         END;
         RETURN v_nro_tarjeta;
      EXCEPTION
         WHEN OTHERS THEN
            p_mensaje := 'Error en el proceso de busqueda de tarjetas para la cuenta ' ||
                         p_nro_cuenta || '; ' || SQLERRM;
            RETURN NULL;
      END;
      /**********************************************************************
      ********************* INICIO DE PROCESO PRINCIPAL *********************
      **********************************************************************/
   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
      /*\** Se verifica que no se corra 2 veces el proceso en el mismo dia. **\
      SELECT MAX(cd.fec_envio) INTO v_fec_control FROM co_inf_cob_diarios cd;
      IF trunc(v_fec_control) = trunc(c_fec_actual) THEN
         \** para asegurar que no corran 2 veces el proceso en el mismo dia. **\
         raise_application_error(-20000,
                                 'Error Cobros de Fecha ' || to_char(c_fec_actual, 'DD/MM/YYYY') ||
                                  ' ya procesados. No se puede volver a procesar en el mismo dia! ');
      END IF;*/
      /** Busca los parámetros para el proceso. **/
      v_nro     := '1-Inicio';
      v_mensaje := NULL;
      BEGIN
         SELECT MAX(fec_envio) INTO v_fec_ult_env FROM co_inf_cob_diarios;
      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            v_mensaje := 'No se pudo obtener la fecha de último proceso para Informconf ' ||
                         SQLERRM;
            RAISE v_error;
      END;

      IF v_fec_ult_env IS NULL THEN
         /** La primera vez se toma desde el dia anterior. **/
         v_fec_ult_env := c_fec_actual - 1;
      END IF;
      v_regs        := 0;
      v_old_nro_cta := NULL;
      v_old_nro_cuo := NULL;
      /** Cursor de Inclusiones para Informconf. **/
      v_nro := '3.11- Al buscar en el cursor de inclusiones';
      /** Cursor de Inclusiones para Informconf. **/
      FOR i IN inclusiones('N') LOOP
         v_nro := '3.12- Al ingresar al archivo de inclusiones';
         IF nvl(v_old_nro_cta, ' ') <> i.nro_cuenta OR nvl(v_old_nro_cuo, 0) <> i.nro_cuota THEN
            v_regs := nvl(v_regs, 0) + 1;
            v_nro  := '34-Obt. Direcciones';
            pre_obt_direccion(i.cod_persona, v_dir_par, v_dir_lab, v_dir_lab_alt);
            v_nro := '35-Obt. Telefonos';
            pre_obt_telefono(i.cod_persona, v_tel_par, v_tel_lab, v_tel_lab_alt);
            v_nro                         := '37- Ins. Datos';
            v_tip_cobro                   := NULL;
            v_fec_pago                    := NULL;
            v_mto_pago                    := NULL;
            r_linea                       := NULL;
            r_linea.cod_persona           := i.cod_persona;
            r_linea.nro_cuenta            := i.nro_cuenta;
            r_linea.nro_cuota             := nvl(i.nro_cuota, 0);
            r_linea.cod_modulo            := i.cod_modulo;
            r_linea.cod_modalidad         := i.cod_modalidad;
            r_linea.cod_moneda            := i.cod_moneda;
            r_linea.nro_documento         := i.nro_documento;
            r_linea.pri_nombre            := i.pri_nombre;
            r_linea.seg_nombre            := i.seg_nombre;
            r_linea.pri_apellido          := i.pri_apellido;
            r_linea.seg_apellido          := i.seg_apellido;
            r_linea.ape_casada            := i.ape_casada;
            r_linea.dir_particular        := v_dir_par;
            r_linea.dir_laboral           := v_dir_lab;
            r_linea.dir_lab_alternativo   := v_dir_lab_alt;
            r_linea.tel_particular        := v_tel_par;
            r_linea.tel_laboral           := v_tel_lab;
            r_linea.tel_lab_alternativo   := v_tel_lab_alt;
            r_linea.fec_operacion         := i.fec_operacion;
            r_linea.can_cuotas            := i.can_cuotas;
            r_linea.tip_inf_operacion     := i.tip_operacion;
            r_linea.pri_cuo_atrasada      := i.pri_cuo_atrasada;
            r_linea.can_cuo_atrasada      := i.can_cuo_atrasada;
            r_linea.mto_cuota             := i.mto_cuota;
            r_linea.fec_vencimiento       := i.pri_fec_ven_atrasada;
            r_linea.fec_ult_pago          := i.fec_ult_pago;
            r_linea.tip_inf_garantia      := lf_obt_garantia(i.nro_cuenta, i.cod_modulo,
                                                             i.observacion);
            r_linea.tip_inf_moneda        := i.tip_moneda;
            r_linea.mto_deuda             := i.sal_mora;
            r_linea.fec_final             := i.fec_final;
            r_linea.tip_inf_cobro         := v_tip_cobro;
            r_linea.mto_cobrado           := v_mto_pago;
            r_linea.fec_cobro             := v_fec_pago;
            r_linea.tip_inf_actualizacion := NULL;
            r_linea.inf_periodicidad      := i.periodicidad;
            r_linea.observacion           := TRIM(i.observacion);
            r_linea.nro_cta_nueva         := i.nro_cta_nueva;
            r_linea.cod_ori_modulo        := i.cod_ori_modulo;
            r_linea.cod_ori_modalidad     := i.cod_ori_modalidad;
            r_linea.cod_sec_credito       := i.cod_sec_credito;

            IF r_linea.cod_modulo = 5 THEN
               r_linea.nro_tarjeta := lf_obt_tarjeta(r_linea.nro_cuenta, r_linea.observacion,
                                                     v_mensaje);
            END IF;
            /** Cargamos el monto de Sobregiro o el monto de Tarjeta Vencida. **/
            IF i.tip_operacion = 4 OR (i.cod_modulo = 5 AND i.observacion = 'INC-1.4') THEN
               /** Cargamos el total de la deuda(=mto_cuota), fec_vto=fec_ope en sobregiros. **/
               r_linea.mto_cuota       := i.sal_mora;
               r_linea.mto_deuda       := r_linea.mto_cuota;
               r_linea.fec_vencimiento := i.fec_operacion;
               r_linea.dia_atraso      := i.dias_atraso;
            END IF;

            BEGIN
               v_existe := 0;
               /** Verificamos si ya existe. **/
               BEGIN
                  SELECT COUNT(*)
                    INTO v_existe
                    FROM co_inf_cob_diarios w
                   WHERE trunc(w.fec_envio) = trunc(c_fec_actual)
                     AND w.cod_persona = r_linea.cod_persona
                     AND w.nro_cuenta = r_linea.nro_cuenta
                     AND w.nro_cuota = r_linea.nro_cuota
                     AND w.cod_modulo = r_linea.cod_modulo
                     AND w.cod_modalidad = r_linea.cod_modalidad
                     AND w.tip_envio = 'I';
               EXCEPTION
                  WHEN no_data_found THEN
                     v_existe := 0;
               END;
               IF v_existe = 0 THEN
                  v_nro := '37' || i.cod_persona;
                  pao_cob.pr_gen_inf_linea(r_linea, 'I');
               END IF;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  v_mensaje := 'Se produjo un error al generar la línea ' || SQLERRM;
                  RAISE v_error;
            END;
         END IF;
         r_linea.nro_cuota := i.nro_cuota;
         v_nro             := '38-Borra co_inf_cob_personas';
         /** Buscamos si no existe aun en co_inf_cob_personas, de no ser asi insertamos. **/
         v_existe := 0;
         BEGIN
            SELECT COUNT(*)
              INTO v_existe
              FROM co_inf_cob_personas a
             WHERE a.cod_persona = r_linea.cod_persona
               AND a.nro_cuenta = r_linea.nro_cuenta
               AND a.nro_cuota = r_linea.nro_cuota;
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 0;
         END;

         IF v_existe = 0 THEN
            BEGIN
               INSERT INTO co_inf_cob_personas
                  (cod_usu_gestion, cod_persona, nro_cuenta, nro_cuota, cod_modulo, cod_modalidad,
                   cod_moneda, fec_ini_envio, nro_documento, pri_nombre, seg_nombre, pri_apellido,
                   seg_apellido, ape_casada, dir_particular, dir_laboral, dir_lab_alternativo,
                   tel_particular, tel_laboral, tel_lab_alternativo, fec_operacion, can_cuotas,
                   tip_inf_operacion, pri_cuo_atrasada, can_cuo_atrasada, mto_cuota, fec_vencimiento,
                   fec_ult_pago, tip_inf_garantia, tip_inf_moneda, mto_deuda, fec_final,
                   tip_inf_cobro, mto_cobrado, fec_cobro, tip_inf_actualizacion, inf_periodicidad,
                   nro_tarjeta, observacion, nro_cta_nueva, cod_ori_modulo, cod_ori_modalidad,
                   cod_sec_credito)
               VALUES
                  (r_linea.cod_usu_gestion, r_linea.cod_persona, r_linea.nro_cuenta,
                   r_linea.nro_cuota, r_linea.cod_modulo, r_linea.cod_modalidad, r_linea.cod_moneda,
                   c_fec_actual, r_linea.nro_documento, r_linea.pri_nombre, r_linea.seg_nombre,
                   r_linea.pri_apellido, r_linea.seg_apellido, r_linea.ape_casada,
                   r_linea.dir_particular, r_linea.dir_laboral, r_linea.dir_lab_alternativo,
                   r_linea.tel_particular, r_linea.tel_laboral, r_linea.tel_lab_alternativo,
                   r_linea.fec_operacion, r_linea.can_cuotas, r_linea.tip_inf_operacion,
                   r_linea.pri_cuo_atrasada, r_linea.can_cuo_atrasada, r_linea.mto_cuota,
                   r_linea.fec_vencimiento, r_linea.fec_ult_pago, r_linea.tip_inf_garantia,
                   r_linea.tip_inf_moneda, r_linea.mto_deuda, r_linea.fec_final,
                   r_linea.tip_inf_cobro, r_linea.mto_cobrado, r_linea.fec_cobro,
                   r_linea.tip_inf_actualizacion, r_linea.inf_periodicidad, r_linea.nro_tarjeta,
                   TRIM(r_linea.observacion), r_linea.nro_cta_nueva, r_linea.cod_ori_modulo,
                   r_linea.cod_ori_modalidad, r_linea.cod_sec_credito);
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  v_mensaje := 'No se pudo insertar la cuenta ' || r_linea.nro_cuenta || '/' ||
                               to_char(r_linea.nro_cuota) || '; ' || SQLERRM;
                  RAISE v_error;
            END;
         END IF;
         v_nro         := '39';
         v_old_nro_cta := i.nro_cuenta;
         v_old_nro_cuo := i.nro_cuota;
      END LOOP;
      /**************** FIN DE CURSOR DE INCLUSIONES ****************/
      v_nro         := '2-Antes Cur.Modif.';
      v_old_nro_cta := NULL;
      v_old_nro_cuo := NULL;
      /***************** Cursor de Modificaciones para Informconf *****************/
      FOR m IN modificaciones LOOP
         IF nvl(v_old_nro_cta, ' ') <> m.nro_cuenta OR nvl(v_old_nro_cuo, 0) <> m.nro_cuota THEN
            IF nvl(r_linea.tip_inf_actualizacion, 'x') = 'P'
            --AND  NOT ((m.cod_modulo= 4) or (m.cod_modulo =5 and m.observacion ='MOD-1.5') or (m.observacion ='MOD-1.7'))
             THEN
               v_nro := '27.1-Al borrar co_inf_cob_personas';
               BEGIN
                  DELETE co_inf_cob_personas
                   WHERE cod_persona = r_linea.cod_persona
                     AND nro_cuenta = r_linea.nro_cuenta
                        --********************************
                     AND cod_modulo = r_linea.cod_modulo
                     AND nro_cuota = r_linea.nro_cuota;
                  /** Se modifica porque nro_cuota = 0 en tarjetas y sobregiro. **/
                  --and tip_inf_operacion= r_linea.tip_inf_operacion;
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     v_mensaje := 'No se pudo eliminar la cuenta ' || r_linea.nro_cuenta || '; ' ||
                                  SQLERRM;
                     RAISE v_error;
               END;
               v_nro := '27.2-Al Insertar pro_gen_inf_linea';
            END IF;
            IF v_old_nro_cta IS NOT NULL THEN
               BEGIN
                  pao_cob.pr_gen_inf_linea(r_linea, 'M');
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     v_mensaje := 'Se produjo un error al generar la línea al:' || v_nro || '-' ||
                                  SQLERRM;
                     RAISE v_error;
               END;
            END IF;
            r_linea := NULL;
            v_nro   := '20-Obt. Direcc.';
            pre_obt_direccion(m.cod_persona, v_dir_par, v_dir_lab, v_dir_lab_alt);
            v_nro := '21-Obt. Tel';
            pre_obt_telefono(m.cod_persona, v_tel_par, v_tel_lab, v_tel_lab_alt);
            v_nro                    := '22-Obt.Tip.Garantia';
            r_linea.tip_inf_garantia := lf_obt_garantia(m.nro_cuenta, m.cod_modulo, m.observacion);
         END IF;
         v_nro := '22-Obt.Pago';
         /** Obtenemos los datos del cobro (Si es préstamo o tarjeta). **/
         IF (m.cod_modulo = 6) OR
            (m.cod_modulo = 5 AND m.observacion NOT IN ('MOD-1.5', 'MOD-1.9')) THEN
            /** Modificado para incluir cantidad de cuotas que debía. **/
            lp_obt_pago(m.nro_cuenta, m.nro_cuota, m.cod_modulo, v_tip_cobro, v_fec_pago,
                        v_mto_pago, m.tip_actualizacion, m.can_cuo_atrasada);
         ELSIF (m.cod_modulo = 4) OR (m.cod_modulo = 5 AND m.observacion = 'MOD-1.5') OR
               (m.observacion = 'MOD-1.7') OR (m.observacion = 'MOD-1.9') THEN
            /** Si es de Sobregiros o Tarjetas Vencidas. **/
            IF (m.observacion <> 'MOD-1.6') AND NOT m.observacion IN ('MOD-1.7', 'MOD-1.9') THEN
               /** Si es de Sobregiros o Tarjetas Vencidas verificamos el estado de la cuenta en ov_cta_vencidas. **/
               SELECT s.estado
                 INTO v_estado
                 FROM ov_cta_vencidas s
                WHERE s.nro_cta_origen = m.nro_cuenta;

               IF v_estado = 'C' THEN
                  /** Pagó todo el Sobregiro o la Tarjeta Vencida. **/
                  v_tip_cobro := 'T';
                  v_mto_pago  := m.mto_cuota;
               ELSE
                  /** Pagó parte del Sobregiro o Tarjeta Vencida. **/
                  v_tip_cobro := 'P';
                  /** Obtenemos lo que pago. **/
                  SELECT nvl(w.mto_total, 0)
                    INTO v_mto_pagado
                    FROM ov_cobros w
                   WHERE w.nro_cuenta = m.nro_cta_nueva
                     AND trunc(w.fecha) = trunc(c_fec_actual)
                     AND rownum = 1;

                  /** El monto pagado es el monto que debia - Sal_total(Lo que debe actualmente). **/
                  v_mto_pago := nvl(v_mto_pagado, 0); --nvl(m.mto_cuota,0) - nvl(v_mto_pagado,0);
               END IF;
               v_fec_pago := c_fec_actual;

            ELSIF m.observacion = 'MOD-1.6' THEN
               v_nro := 'VOY A OBTENER 2:' || m.observacion;
               /***** Aqui ingresa si es es Cta. Cte. *****/
               /** Verificamos el estado de la cuenta en cc_cta_corrientes. **/
               SELECT nvl(r.can_dias, 0)
                 INTO v_nro_1
                 FROM cc_cta_corrientes s, cc_sobregiros_res r
                WHERE s.nro_cuenta = m.nro_cuenta
                  AND s.nro_cuenta = r.nro_cuenta(+);

               IF v_nro_1 = 0 THEN
                  /** Pagó toda la deuda de CC_CTA_CORRIENTES. **/
                  v_tip_cobro := 'T';
                  v_mto_pago  := m.mto_cuota;
               ELSE
                  /** Pagó parte de su CC_CTA_CORRIENTES. **/
                  v_tip_cobro := 'P';
                  /** Obtenemos el saldo actual de la cuenta. **/
                  SELECT nvl(abs(w.sal_total), 0)
                    INTO v_mto_pagado
                    FROM cc_cta_corrientes w
                   WHERE w.nro_cuenta = m.nro_cuenta
                     AND rownum = 1;
                  /** El monto pagado es el monto que debia - Sal_total(Lo que debe actualmente). **/
                  v_mto_pago := nvl(m.mto_cuota, 0) - nvl(v_mto_pagado, 0);
               END IF;
               v_fec_pago := c_fec_actual;

            ELSIF m.observacion = 'MOD-1.7' THEN
               /***** Aquí ingresa si es Cta. Cte. y se aumenta su deuda. *****/
               /** Pagó parte de su CC_CTA_CORRIENTES. **/
               v_tip_cobro := 'P';
               /** Obtenemos el saldo actual de la cuenta. Buscamos el nuevo monto de mora. **/
               SELECT nvl(abs(r.mto_mora), 0)
                 INTO v_mto_pagado
                 FROM cc_cta_corrientes w, cc_sobregiros_res r
                WHERE w.nro_cuenta = m.nro_cuenta
                  AND w.nro_cuenta = r.nro_cuenta(+)
                  AND rownum = 1;
               /** El monto pagado es lo que se le va a enviar como 'D'. **/
               v_mto_pago := nvl(v_mto_pagado, 0);
               v_fec_pago := NULL;
            ELSIF m.observacion = 'MOD-1.9' THEN
               /** Aquí ingresa si ya se envio como cuenta corriente o tarjeta y al pasar a vencidas aumento su deuda. **/
               v_tip_cobro := 'P';
               /** Buscamos el nuevo saldo total. **/
               SELECT nvl(abs(w.sal_total), 0)
                 INTO v_mto_pagado
                 FROM ov_cta_vencidas w
                WHERE w.nro_cta_origen = m.nro_cuenta
                  AND rownum = 1;
               /** El monto pagado es lo que se le va aenviar como 'D'. **/
               v_mto_pago := nvl(v_mto_pagado, 0);
               v_fec_pago := NULL;
            END IF;
            /** Fin de verificación. **/
         END IF;
         v_nro                       := '23-Insertar Linea';
         r_linea.cod_persona         := m.cod_persona;
         r_linea.nro_cuenta          := m.nro_cuenta;
         r_linea.nro_cuota           := m.nro_cuota;
         r_linea.cod_modulo          := m.cod_modulo;
         r_linea.cod_modalidad       := m.cod_modalidad;
         r_linea.cod_moneda          := m.cod_moneda;
         r_linea.nro_documento       := m.nro_documento;
         r_linea.pri_nombre          := m.pri_nombre;
         r_linea.seg_nombre          := m.seg_nombre;
         r_linea.pri_apellido        := m.pri_apellido;
         r_linea.seg_apellido        := m.seg_apellido;
         r_linea.ape_casada          := m.ape_casada;
         r_linea.dir_particular      := v_dir_par;
         r_linea.dir_laboral         := v_dir_lab;
         r_linea.dir_lab_alternativo := v_dir_lab_alt;
         r_linea.tel_particular      := v_tel_par;
         r_linea.tel_laboral         := v_tel_lab;
         r_linea.tel_lab_alternativo := v_tel_lab_alt;
         r_linea.fec_operacion       := m.fec_operacion;
         r_linea.can_cuotas          := m.can_cuotas;
         r_linea.tip_inf_operacion   := m.tip_operacion;
         r_linea.pri_cuo_atrasada    := m.pri_cuo_atrasada;
         r_linea.can_cuo_atrasada    := m.can_cuo_atrasada;
         r_linea.mto_cuota           := m.mto_cuota;
         r_linea.fec_vencimiento     := m.pri_fec_ven_atrasada;
         r_linea.fec_ult_pago        := m.fec_ult_pago;
         r_linea.tip_inf_moneda      := m.tip_moneda;
         IF ((m.cod_modulo = 4) OR (m.cod_modulo = 5 AND m.observacion = 'MOD-1.5')) AND
            m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            IF m.sal_mora = nvl(v_mto_pago, 0) THEN
               r_linea.mto_deuda := 0;
            ELSE
               r_linea.mto_deuda := nvl(m.sal_mora, 0) - nvl(v_mto_pago, 0);
               r_linea.mto_cuota := nvl(m.sal_mora, 0) - nvl(v_mto_pago, 0);
            END IF;
         ELSIF m.observacion IN ('MOD-1.7', 'MOD-1.9') THEN
            r_linea.mto_deuda := nvl(v_mto_pago, 0);
            r_linea.mto_cuota := nvl(v_mto_pago, 0);

         ELSIF ((m.cod_modulo = 6) OR (m.cod_modulo = 5 AND m.observacion <> 'MOD-1.5')) AND
               m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            IF nvl(m.sal_mora, 0) = nvl(v_mto_pago, 0) THEN
               r_linea.mto_deuda := 0;
            ELSE
               r_linea.mto_deuda := nvl(m.sal_mora, 0) - nvl(v_mto_pago, 0);
               r_linea.mto_cuota := nvl(m.sal_mora, 0) - nvl(v_mto_pago, 0);
            END IF;
         END IF;
         IF (m.cod_modulo = 6) AND m.observacion IN ('MOD-1.3', 'MOD-1.1') THEN
            /** Obtenemos el monto de Cuota de la tabla pr_cuotas acorde a la nueva cuota enviada. **/
            BEGIN
               SELECT nvl(u.mto_capital, 0) + nvl(u.mto_interes, 0)
                 INTO r_linea.mto_cuota
                 FROM pr_cuotas u
                WHERE u.nro_cuota = m.nro_cuota
                  AND u.nro_cuenta = m.nro_cuenta;
            EXCEPTION
               WHEN no_data_found THEN
                  r_linea.mto_cuota := r_linea.mto_cuota;
            END;
         END IF;

         r_linea.fec_final        := m.fec_final;
         r_linea.tip_inf_cobro    := v_tip_cobro;
         r_linea.fec_cobro        := v_fec_pago;
         r_linea.inf_periodicidad := m.periodicidad;
         r_linea.observacion      := TRIM(m.observacion);
         IF (m.cod_modulo = 5 OR m.cod_modulo = 6) AND m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            r_linea.dia_atraso := nvl(m.dias_atraso, 0);
         END IF;
         IF r_linea.nro_tarjeta IS NULL AND r_linea.cod_modulo = 5 THEN
            /** Debe de buscar la tarjeta en ambos criterios. **/
            --and m.observacion not IN ('MOD-1.7','MOD-1.9')THEN
            r_linea.nro_tarjeta := lf_obt_tarjeta(r_linea.nro_cuenta, r_linea.observacion, v_mensaje);
         END IF;
         IF (m.cod_modulo = 6) OR (m.cod_modulo = 5 AND m.observacion <> 'MOD-1.5') AND
            m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            --r_linea.cod_modulo in (5,6) then
            IF nvl(m.tip_actualizacion, 'x') = 'P' THEN
               r_linea.tip_inf_actualizacion := 'P';
               r_linea.mto_cobrado           := nvl(r_linea.mto_cobrado, 0) + nvl(v_mto_pago, 0);
            ELSE
               r_linea.tip_inf_actualizacion := 'D';
               r_linea.mto_cobrado           := v_mto_pago;
            END IF;
         ELSIF (m.cod_modulo = 4 OR (m.cod_modulo = 5 AND m.observacion = 'MOD-1.5')) AND
               m.observacion NOT IN ('MOD-1.7', 'MOD-1.9') THEN
            --else
            /** Si es sobregiros. **/
            r_linea.tip_inf_actualizacion := 'P';
            r_linea.mto_cobrado           := v_mto_pago;

         ELSIF m.observacion IN ('MOD-1.7', 'MOD-1.9') THEN
            r_linea.tip_inf_actualizacion := 'D';
            r_linea.mto_cobrado           := 0;
            r_linea.fec_ult_pago          := NULL;
            r_linea.mto_cobrado           := NULL;
            r_linea.nro_cta_nueva         := m.nro_cta_nueva;
            r_linea.dia_atraso            := m.dias_atraso;

         END IF;
         v_nro := '24-Update de co_inf_cob_personas';
         IF nvl(m.tip_actualizacion, 'x') <> 'P' THEN
            BEGIN
               UPDATE co_inf_cob_personas
                  SET cod_usu_gestion       = r_linea.cod_usu_gestion,
                      cod_persona           = r_linea.cod_persona,
                      nro_cuenta            = r_linea.nro_cuenta,
                      nro_cuota             = r_linea.nro_cuota,
                      cod_modulo            = r_linea.cod_modulo,
                      cod_modalidad         = r_linea.cod_modalidad,
                      cod_moneda            = r_linea.cod_moneda,
                      nro_documento         = r_linea.nro_documento,
                      pri_nombre            = r_linea.pri_nombre,
                      seg_nombre            = r_linea.seg_nombre,
                      pri_apellido          = r_linea.pri_apellido,
                      seg_apellido          = r_linea.seg_apellido,
                      ape_casada            = r_linea.ape_casada,
                      dir_particular        = r_linea.dir_particular,
                      dir_laboral           = r_linea.dir_laboral,
                      dir_lab_alternativo   = r_linea.dir_lab_alternativo,
                      tel_particular        = r_linea.tel_particular,
                      tel_laboral           = r_linea.tel_laboral,
                      tel_lab_alternativo   = r_linea.tel_lab_alternativo,
                      fec_operacion         = r_linea.fec_operacion,
                      can_cuotas            = r_linea.can_cuotas,
                      tip_inf_operacion     = r_linea.tip_inf_operacion,
                      pri_cuo_atrasada      = r_linea.pri_cuo_atrasada,
                      can_cuo_atrasada      = r_linea.can_cuo_atrasada,
                      mto_cuota             = r_linea.mto_cuota,
                      fec_vencimiento       = r_linea.fec_vencimiento,
                      fec_ult_pago          = r_linea.fec_ult_pago,
                      tip_inf_garantia      = r_linea.tip_inf_garantia,
                      tip_inf_moneda        = r_linea.tip_inf_moneda,
                      mto_deuda             = r_linea.mto_deuda,
                      fec_final             = r_linea.fec_final,
                      tip_inf_cobro         = r_linea.tip_inf_cobro,
                      mto_cobrado           = r_linea.mto_cobrado,
                      fec_cobro             = r_linea.fec_cobro,
                      tip_inf_actualizacion = r_linea.tip_inf_actualizacion,
                      inf_periodicidad      = r_linea.inf_periodicidad,
                      nro_tarjeta           = r_linea.nro_tarjeta,
                      observacion           = TRIM(r_linea.observacion),
                      dia_atraso            = nvl(r_linea.dia_atraso, 0),
                      nro_cta_nueva         = r_linea.nro_cta_nueva,
                      cod_sec_credito       = r_linea.cod_sec_credito
                WHERE cod_persona = r_linea.cod_persona
                  AND nro_cuenta = r_linea.nro_cuenta
                  AND nro_cuota = r_linea.nro_cuota;

               IF SQL%NOTFOUND THEN
                  v_nro := '26- Insertar en co_inf_cob_personas';
                  BEGIN
                     INSERT INTO co_inf_cob_personas
                        (cod_usu_gestion, cod_persona, nro_cuenta, nro_cuota, cod_modulo,
                         cod_modalidad, cod_moneda, fec_ini_envio, nro_documento, pri_nombre,
                         seg_nombre, pri_apellido, seg_apellido, ape_casada, dir_particular,
                         dir_laboral, dir_lab_alternativo, tel_particular, tel_laboral,
                         tel_lab_alternativo, fec_operacion, can_cuotas, tip_inf_operacion,
                         pri_cuo_atrasada, can_cuo_atrasada, mto_cuota, fec_vencimiento,
                         fec_ult_pago, tip_inf_garantia, tip_inf_moneda, mto_deuda, fec_final,
                         tip_inf_cobro, mto_cobrado, fec_cobro, tip_inf_actualizacion,
                         inf_periodicidad, nro_tarjeta, dia_atraso, observacion, nro_cta_nueva,
                         cod_ori_modulo, cod_ori_modalidad,cod_sec_credito)
                     VALUES
                        (r_linea.cod_usu_gestion, r_linea.cod_persona, r_linea.nro_cuenta,
                         r_linea.nro_cuota, r_linea.cod_modulo, r_linea.cod_modalidad,
                         r_linea.cod_moneda, c_fec_actual, r_linea.nro_documento, r_linea.pri_nombre,
                         r_linea.seg_nombre, r_linea.pri_apellido, r_linea.seg_apellido,
                         r_linea.ape_casada, r_linea.dir_particular, r_linea.dir_laboral,
                         r_linea.dir_lab_alternativo, r_linea.tel_particular, r_linea.tel_laboral,
                         r_linea.tel_lab_alternativo, r_linea.fec_operacion, r_linea.can_cuotas,
                         r_linea.tip_inf_operacion, r_linea.pri_cuo_atrasada,
                         r_linea.can_cuo_atrasada, r_linea.mto_cuota, r_linea.fec_vencimiento,
                         r_linea.fec_ult_pago, r_linea.tip_inf_garantia, r_linea.tip_inf_moneda,
                         r_linea.mto_deuda, r_linea.fec_final, r_linea.tip_inf_cobro,
                         r_linea.mto_cobrado, r_linea.fec_cobro, r_linea.tip_inf_actualizacion,
                         r_linea.inf_periodicidad, r_linea.nro_tarjeta, r_linea.dia_atraso,
                         TRIM(r_linea.observacion), r_linea.nro_cta_nueva, r_linea.cod_ori_modulo,
                         r_linea.cod_ori_modalidad,r_linea.cod_sec_credito);
                  EXCEPTION
                     WHEN v_error THEN
                        RAISE v_error;
                     WHEN OTHERS THEN
                        v_mensaje := 'Lugar:' || v_nro || '-' || 'No se pudo insertar la cuenta ' ||
                                     r_linea.nro_cuenta || '/' || to_char(r_linea.nro_cuota) || '; ' ||
                                     SQLERRM;
                        RAISE v_error;
                  END;
               END IF;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  v_mensaje := 'Lugar:' || v_nro || '-' || 'No se pudo actualizar la cuenta ' ||
                               r_linea.nro_cuenta || '/' || to_char(r_linea.nro_cuota) || '; ' ||
                               SQLERRM;
                  RAISE v_error;
            END;
         END IF;
         /** Borramos los Sobregiros. **/
         IF (r_linea.cod_modulo = 4 AND nvl(r_linea.tip_inf_actualizacion, 'X') = 'P') THEN
            DELETE co_inf_cob_personas
             WHERE cod_persona = r_linea.cod_persona
               AND nro_cuenta = r_linea.nro_cuenta
               AND nro_cuota = r_linea.nro_cuota
                  /** Se modifica porque nro_cuota=0 en tarjetas y sobregiro. **/
               AND tip_inf_operacion = r_linea.tip_inf_operacion;
         ELSIF (r_linea.cod_modulo = 6 AND nvl(r_linea.tip_inf_actualizacion, 'X') = 'D') THEN
            v_cantidad := 9999;
            BEGIN
               SELECT COUNT(*)
                 INTO v_cantidad
                 FROM co_inf_cob_diarios x
                WHERE x.nro_cuenta = r_linea.nro_cuenta
                  AND x.tip_envio = 'M'
                  AND x.observacion = 'MOD-1.3'
                  AND x.fec_envio = r_linea.fec_operacion;
            EXCEPTION
               WHEN no_data_found THEN
                  v_cantidad := 9999;
            END;
            IF v_cantidad <> 9999 THEN
               DELETE FROM co_inf_cob_diarios x
                WHERE x.nro_cuenta = r_linea.nro_cuenta
                  AND x.tip_envio = 'M'
                  AND x.observacion = 'MOD-1.3'
                  AND x.tip_inf_actualizacion = 'P'
                  AND x.fec_envio = r_linea.fec_operacion;
            END IF;
         END IF;
         v_old_nro_cta := m.nro_cuenta;
         v_old_nro_cuo := m.nro_cuota;
      END LOOP;
      /********************** Fin de Cursor de Modificación **********************/
      IF (nvl(r_linea.tip_inf_actualizacion, 'x') = 'P')
      --or  ((r_linea.cod_modulo=4 OR (r_linea.cod_modulo =5 and r_linea.observacion ='MOD-1.5'))))
      --and r_linea.tip_inf_cobro='T'
       THEN
         v_nro := '27- Al Borrar co_inf_cob_personas ';
         BEGIN
            DELETE co_inf_cob_personas
             WHERE cod_persona = r_linea.cod_persona
               AND nro_cuenta = r_linea.nro_cuenta
               AND nro_cuota = r_linea.nro_cuota
                  /** nro_cuota = 0 para Sobregiro y Tarjetas. **/
               AND tip_inf_operacion = r_linea.tip_inf_operacion;

         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               v_mensaje := 'No se pudo eliminar la cuenta ' || r_linea.nro_cuenta || '; ' ||
                            SQLERRM;
               RAISE v_error;
         END;
      END IF;
      IF v_old_nro_cta IS NOT NULL THEN
         BEGIN
            pr_gen_inf_linea(r_linea, 'M');
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               v_mensaje := 'Se produjo un error al generar la línea ' || SQLERRM;
               RAISE v_error;
         END;
      END IF;
      /** Eliminar para informar como incluidas las cuotas de cuentas informadas en modificación por cobro. **/
      BEGIN
         IF (nvl(r_linea.tip_inf_actualizacion, 'x') = 'P') THEN
            DELETE co_inf_cob_personas e
             WHERE e.nro_cuota > (SELECT MAX(nro_cuota)
                                    FROM co_inf_cob_diarios d
                                   WHERE e.nro_cuenta = d.nro_cuenta
                                     AND d.fec_envio = c_fec_actual
                                     AND e.cod_modulo = d.cod_modulo
                                     AND e.tip_inf_operacion = d.tip_inf_operacion);
         END IF;
      END;

      v_nro := '3- Al ingresar en el archivo de exclusiones';
      /***************** Cursor de Exclusiones para Informconf *****************/
      FOR e IN exclusiones LOOP
         v_nro := '8-Obt.  Direcciones';
         /** Obtiene la Dirección Particular, Laboral y Laboral Alternativa del Cliente. **/
         pre_obt_direccion(e.cod_persona, v_dir_par, v_dir_lab, v_dir_lab_alt);
         v_nro := '9-Obt. Telefonos';
         /** Obtiene el Nro. de Teléfono Particular, Laboral y Laboral Alternativa del Cliente. **/
         pre_obt_telefono(e.cod_persona, v_tel_par, v_tel_lab, v_tel_lab_alt);
         v_nro                         := '10-Ins. Linea';
         r_linea                       := NULL;
         r_linea.cod_persona           := e.cod_persona;
         r_linea.nro_cuenta            := e.nro_cuenta;
         r_linea.nro_cuota             := e.nro_cuota;
         r_linea.cod_modulo            := e.cod_modulo;
         r_linea.cod_modalidad         := e.cod_modalidad;
         r_linea.cod_moneda            := e.cod_moneda;
         r_linea.nro_documento         := e.nro_documento;
         r_linea.pri_nombre            := e.pri_nombre;
         r_linea.seg_nombre            := e.seg_nombre;
         r_linea.pri_apellido          := e.pri_apellido;
         r_linea.seg_apellido          := e.seg_apellido;
         r_linea.ape_casada            := e.ape_casada;
         r_linea.dir_particular        := v_dir_par;
         r_linea.dir_laboral           := v_dir_lab;
         r_linea.dir_lab_alternativo   := v_dir_lab_alt;
         r_linea.tel_particular        := v_tel_par;
         r_linea.tel_laboral           := v_tel_lab;
         r_linea.tel_lab_alternativo   := v_tel_lab_alt;
         r_linea.fec_operacion         := e.fec_operacion;
         r_linea.can_cuotas            := e.can_cuotas;
         r_linea.tip_inf_operacion     := e.tip_inf_operacion;
         r_linea.pri_cuo_atrasada      := e.pri_cuo_atrasada;
         r_linea.can_cuo_atrasada      := e.can_cuo_atrasada;
         r_linea.mto_cuota             := e.mto_cuota;
         r_linea.fec_vencimiento       := e.fec_vencimiento;
         r_linea.fec_ult_pago          := e.fec_ult_pago;
         r_linea.tip_inf_garantia      := e.tip_inf_garantia;
         r_linea.tip_inf_moneda        := e.tip_inf_moneda;
         r_linea.mto_deuda             := e.mto_deuda;
         r_linea.fec_final             := e.fec_final;
         r_linea.tip_inf_cobro         := NULL;
         r_linea.mto_cobrado           := e.mto_cobrado;
         r_linea.fec_cobro             := e.fec_cobro;
         r_linea.tip_inf_actualizacion := NULL;
         r_linea.inf_periodicidad      := e.inf_periodicidad;
         r_linea.nro_tarjeta           := e.nro_tarjeta;
         r_linea.observacion           := TRIM(e.observacion);

         BEGIN
            pao_cob.pr_gen_inf_linea(r_linea, 'E');
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               v_mensaje := 'Se produjo un error al generar la línea ' || SQLERRM;
               RAISE v_error;
         END;
         v_nro := '12-Borrar co_inf_cob_personas';
         BEGIN
            DELETE co_inf_cob_personas
             WHERE cod_persona = r_linea.cod_persona
               AND nro_cuenta = r_linea.nro_cuenta
               AND cod_modulo = r_linea.cod_modulo
               AND nro_cuota = r_linea.nro_cuota;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               v_mensaje := 'No se pudo eliminar la cuenta ' || r_linea.nro_cuenta || '/' ||
                            to_char(r_linea.nro_cuota) || '; ' || SQLERRM;
               RAISE v_error;
         END;

      END LOOP;

      v_nro := '40';
      BEGIN
         SELECT COUNT(DISTINCT(cod_persona)) INTO v_can_inf FROM co_inf_cob_personas;
      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            v_can_inf := 0;
      END;
      v_nro         := '48';
      v_can_sol     := 0;
      v_nro         := '49';
      v_regs        := 0;
      v_old_nro_cta := NULL;
      v_old_nro_cuo := NULL;
      /******************* FIN DE PROCESO PRINCIPAL *******************/
      v_nro := '61- Al gen. Ascii';
      /** En la linea inferior llama al Procedimiento que genera el archivo ASCII a ser enviado. **/
      /*IF v_mensaje IS NULL THEN
         pr_gen_inf_archivo;
      END IF;*/
   EXCEPTION
      WHEN v_error THEN
         raise_application_error(-20852, 'ITC-' || ': (' || to_char(v_regs) || ') ' || v_mensaje);
      WHEN OTHERS THEN
         raise_application_error(-20853,
                                 'ITC-' || ': (' || to_char(v_regs) || ') ' ||
                                  'Error en el proceso de control de cobranzas --Nro:' || v_nro || '-' ||
                                  SQLERRM);
   END pr_gen_arc_preventivas;

   /** Importación de archivos RS. **/
   PROCEDURE pr_sco_importacion IS
--      v_referencia  VARCHAR2(30) := 'PER_SCORING';
      v_cod_ente    ge_entes.cod_ente%TYPE := fug_obt_pardinamico('COD_ENT_REC_STRATEGY');
      v_dir_destino VARCHAR2(100) := fug_obt_parentes(v_cod_ente, 'CAR_COMPARTIDA');
      v_fec_actual  date default pag_cal.fu_obt_fec_actual(21);
      v_det_error   varchar2(4000);
      v_hor_inicio  ge_ra_log_ftp.hor_inicio%type;
      v_hor_fin     ge_ra_log_ftp.hor_fin%type;
      cursor c_arc_importacion is
      select a.referencia
        from ge_archivos a
       where a.referencia in ('PER_SCORING');
/*       where a.referencia in ('PER_SCORING','RS_EST_CLIENTES','RS_DOMICILIOS',
                              'RS_AGENDAS','RS_PAGOS','RS_TELEFONOS','RS_GESTIONESREALIZADAS');*/

   -- Procedimiento que ejecuta el proceso posterior si tiene definido
   PROCEDURE p_pos_proceso(p_referencia ge_archivos.referencia%type)  IS
   v_archivo      ge_archivos.archivo%type;
   v_cod_proceso  ge_procesos.cod_proceso%type;
   v_tip_proceso  ge_procesos.tipo%type;
   v_error       varchar2(1000);
   v_sentencia   varchar2(500);
   ---
   cursor c_proceso is
   select a.pos_proceso
     from ge_archivos a
    where a.referencia = p_referencia;
   BEGIN
     for i in c_proceso loop
       if i.pos_proceso is not null then

         v_sentencia := 'BEGIN '||i.pos_proceso||'; END;';
         sql_util.ejecute_dml(v_sentencia, v_error);

         if v_error is not null then
           raise_application_error(-20472, 'Error al Ejecutar proceso Posterior de '||p_referencia||' - ' || SQLERRM);
         end if;

       end if;
     end loop;
   END;

   BEGIN
     v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
     for k in c_arc_importacion loop
       BEGIN
       pag_arc.pr_arc_pro_archivo(k.referencia, v_dir_destino,  trunc(v_fec_actual));
       --
       p_pos_proceso(k.referencia);
       EXCEPTION
         WHEN OTHERS THEN
           IF k.referencia = 'PER_SCORING' THEN
             v_eje_proceso := 'N';
           END IF;
          v_det_error   := substr(sqlerrm,1,4000);
          v_hor_fin     := to_char(sysdate,'hh24:mi:ss');
        -- Insertamos el error del envio al directorio compartido
        IF v_det_error is not null THEN
           INSERT INTO ge_ra_log_ftp
            (fec_envio, nom_archivo, det_error,hor_inicio,hor_fin)
           VALUES
            (SYSDATE, k.referencia, v_det_error,v_hor_inicio,v_hor_fin);
           COMMIT;
        END IF;
     END;
    end loop;
   END pr_sco_importacion;

   /** Importación de los archivos de salida (DIRE, TELE y MAIL) del RecoveryStrategy. **/
   PROCEDURE pr_dat_per_importacion IS
      v_cod_ente    ge_entes.cod_ente%TYPE := fug_obt_pardinamico('COD_ENT_REC_STRATEGY');
      v_dir_destino VARCHAR2(100) := fug_obt_parentes(v_cod_ente, 'CAR_COMPARTIDA');
      v_rec_count   NUMBER := 0;
      v_retorno     VARCHAR2(100) := '';
      CURSOR archivos IS
         SELECT ltrim(rtrim(REPLACE(archivo, '$', to_char(trunc(SYSDATE), for_fecha)))) archivo
           FROM ge_archivos
          WHERE referencia IN ('PER_DIRECCIONES', 'PER_TELEFONOS', 'PER_CORREOS')
          ORDER BY referencia, nro_secuencia;
   BEGIN
      /** Cargar los archivos del FTP. **/
      FOR a IN archivos LOOP
         v_rec_count := v_rec_count + 1;
         v_retorno   := fub_env_ftp_regulador(v_cod_ente, a.archivo);
      END LOOP;
      IF v_rec_count < 1 THEN
         raise_application_error(-20472, 'Error al procesar la importación, archivos no definidos');
      END IF;
      pag_arc.pr_arc_pro_archivo('PER_DIRECCIONES', v_dir_destino, trunc(SYSDATE));
      pag_arc.pr_arc_pro_archivo('PER_TELEFONOS', v_dir_destino, trunc(SYSDATE));
      pag_arc.pr_arc_pro_archivo('PER_CORREOS', v_dir_destino, trunc(SYSDATE));
      pr_ini_circuito;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            --RAISE;
            raise_application_error(-20472, SQLERRM);
         ELSE
            raise_application_error(-20472, 'Error al procesar la importacion; ' || SQLERRM);
         END IF;
   END pr_dat_per_importacion;

   /** Actualizacion de los archivos de salida (DIRE, TELE y MAIL) del RecoveryStrategy. **/
   PROCEDURE pr_act_dat_personas
/*   (
      p_referencia    IN VARCHAR2,
      p_tipo_accion   IN VARCHAR2,
      p_tipo_dato_act IN VARCHAR2
   )*/ IS
   BEGIN
     pro_act_cli_direcciones;
     pro_act_cli_telefonos;
      /*IF p_tipo_accion = 'A' THEN
         \** Aprobar. **\
         IF p_tipo_dato_act = 'D' THEN
            \** Direccion. **\
            UPDATE \*+ BYPASS_UJVC *\ (SELECT a.direccion,
                         a.tipo,
                         a.cod_pais,
                         a.cod_ciudad,
                         a.cod_barrio,
                         a.numero,
                         a.principal,
                         t.calle,
                         t.tip_domicilio,
                         t.origen,
                         t.partido,
                         t.localidad,
                         t.numero numero_new
                    FROM ba_direcciones a, co_per_direcciones_tmp t
                   WHERE a.cod_persona = t.cod_persona
                     AND a.cod_direccion = t.cod_domicilio
                     AND t.cod_per_direccion = p_referencia)
               SET direccion  = calle,
                   tipo       = tip_domicilio,
                   cod_pais   = origen,
                   cod_ciudad = partido,
                   cod_barrio = localidad,
                   numero     = numero_new,
                   principal  = decode(tip_domicilio, 'P', 'S', 'N');

            IF SQL%ROWCOUNT < 1 THEN
               INSERT INTO ba_direcciones
                  (cod_persona, cod_direccion, direccion, tipo, cod_pais, cod_ciudad, cod_barrio,
                   numero, principal)
                  (SELECT cod_persona,
                          cod_domicilio,
                          calle,
                          tip_domicilio,
                          origen,
                          partido,
                          localidad,
                          numero,
                          decode(cod_domicilio, 1, 'S', 'N')
                     FROM co_per_direcciones_tmp t
                    WHERE t.cod_per_direccion = p_referencia);
            END IF;
            \* UPDATE co_per_direcciones_tmp SET estado = 'A' WHERE cod_per_direccion = p_referencia;*\
         ELSIF p_tipo_dato_act = 'T' THEN
            \** Teléfono. **\
            UPDATE \*+ BYPASS_UJVC *\ (SELECT t.numero,
                         t.tip_telefono,
                         t.cod_area,
                         t.extension,
                         t.origen,
                         contacto,
                         a.telefono,
                         a.tipo,
                         a.area,
                         a.interno,
                         a.tip_linea,
                         a.principal
                    FROM ba_telefonos a, co_per_telefonos_tmp t
                   WHERE a.cod_persona = t.cod_persona
                     AND a.cod_telefono = t.cod_telefono
                     AND t.cod_per_telefono = p_referencia)
               SET telefono  = numero,
                   tipo      = tip_telefono,
                   area      = cod_area,
                   interno   = extension,
                   tip_linea = origen,
                   principal = decode(contacto, 0, 'N', 'S');

            IF SQL%ROWCOUNT < 1 THEN
               INSERT INTO ba_telefonos
                  (cod_persona, cod_telefono, telefono, tipo, area, interno, tip_linea, principal)
                  (SELECT cod_persona,
                          cod_telefono,
                          numero,
                          tip_telefono,
                          cod_area,
                          extension,
                          origen,
                          decode(contacto, 0, 'N', 'S')
                     FROM co_per_telefonos_tmp t
                    WHERE t.cod_per_telefono = p_referencia);
            END IF;
            \*UPDATE co_per_telefonos_tmp SET estado = 'A' WHERE cod_per_telefono = p_referencia;*\
         ELSIF p_tipo_dato_act = 'M' THEN
            \** Mail. **\
            UPDATE \*+ BYPASS_UJVC *\ (SELECT t.mail, a.dir_correo
                    FROM ba_personas a, co_per_correos_tmp t
                   WHERE a.cod_persona = t.cod_persona
                     AND t.cod_per_correo = p_referencia)
               SET dir_correo = mail;
            \* UPDATE co_per_correos_tmp SET estado = 'A' WHERE cod_per_correo = p_referencia;*\
         END IF;
         \*  ELSIF p_tipo_accion = 'R' THEN
         -- Rechazar

         IF p_tipo_dato_act = 'D' THEN
            --Direccion
            UPDATE co_per_direcciones_tmp SET estado = 'R' WHERE cod_per_direccion = p_referencia;

         ELSIF p_tipo_dato_act = 'T' THEN
            --Teléfono
            UPDATE co_per_telefonos_tmp SET estado = 'R' WHERE cod_per_telefono = p_referencia;

         ELSIF p_tipo_dato_act = 'M' THEN
            --Mail
            UPDATE co_per_correos_tmp SET estado = 'R' WHERE cod_per_correo = p_referencia;

         END IF;*\
      END IF;*/
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20472, 'Error al procesar la actualizacion; ' || SQLERRM);
         END IF;
   END pr_act_dat_personas;

   /** Inicio del circuito para el WorkFlow.
   Actualización de Datos Personales desde el Recovery Strategy. **/
   PROCEDURE pr_ini_circuito IS
      v_resultado NUMBER(3);
      CURSOR per_direcciones IS
         SELECT cod_per_direccion, cod_persona, estado
           FROM co_per_direcciones_tmp
          WHERE estado IS NULL;

      CURSOR per_telefonos IS
         SELECT cod_per_telefono, cod_persona, estado
           FROM co_per_telefonos_tmp
          WHERE estado IS NULL;

      CURSOR per_correos IS
         SELECT cod_per_correo, cod_persona, estado FROM co_per_correos_tmp WHERE estado IS NULL;
   BEGIN
      /** Inicia el Workflow. **/
      /** Circuito Direcciones. **/
      FOR pd IN per_direcciones LOOP
         v_resultado := paw_cir.fu_ini_circuito(46, pd.cod_per_direccion, pd.cod_persona);
         UPDATE co_per_direcciones_tmp
            SET estado = 'I'
          WHERE cod_per_direccion = pd.cod_per_direccion;
      END LOOP;
      /** Circuito Telefonos. **/
      FOR pt IN per_telefonos LOOP
         v_resultado := paw_cir.fu_ini_circuito(47, pt.cod_per_telefono, pt.cod_persona);
         UPDATE co_per_telefonos_tmp SET estado = 'I' WHERE cod_per_telefono = pt.cod_per_telefono;
      END LOOP;
      /** Circuito Correos. **/
      FOR pc IN per_correos LOOP
         v_resultado := paw_cir.fu_ini_circuito(48, pc.cod_per_correo, pc.cod_persona);
         UPDATE co_per_correos_tmp SET estado = 'I' WHERE cod_per_correo = pc.cod_per_correo;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20472, 'Error al Iniciar el Circuito; ' || SQLERRM);
         END IF;
   END pr_ini_circuito;
   /*Devuelve si la persona tiene o no demanda judicial*/
   FUNCTION fu_ver_cli_judicial(p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
     v_cli_judicial varchar2(1) default 'N';
   BEGIN
     SELECT decode(COUNT(*),0,'N','S')
       INTO v_cli_judicial
       FROM ge_per_inhibidas a
      WHERE cod_persona = p_cod_persona
        AND a.cod_causa = 279 -- demanda judicial
        AND estado = 'I';
     RETURN v_cli_judicial;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
     return 'N';
   END;

   /** Obtiene Tipo del Grupo de Cobranzas del Cliente. **/
   FUNCTION fu_obt_tip_gru_cob(p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
      v_tip_agrupacion     VARCHAR2(1) := NULL;
      v_ope_vencida        NUMBER(1) := NULL;
      v_cli_judicial       VARCHAR2(1) := 'N';
      v_mto_limite         NUMBER(18, 2);
      v_mto_ope_especifica NUMBER(18, 2);
      v_cod_mon_local      ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
      v_tot_riesgo         NUMBER(18, 2);
      v_cli_tot_riesgo     NUMBER(18, 2) := fug_obt_pardinamico('MTO_CLI_TOT_RIESGO');
      v_max_deu_grupo      NUMBER(18,2)  := fug_obt_pardinamico('COB_MAX_DEU_GRUPO');
      v_cod_grupo          ge_clientes.cod_gru_economico%TYPE;
      v_tot_deu_real       ge_gru_economicos.tot_deu_real%TYPE;
      v_lugar number(1);
   BEGIN
   -- si tiene operacion vencida
      BEGIN
         SELECT 3
           INTO v_ope_vencida
           FROM ov_cta_vencidas o, ge_cta_clientes cli
          WHERE o.nro_cta_origen = cli.nro_cuenta
            AND cli.cod_persona = p_cod_persona
            AND ROWNUM = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_ope_vencida := null;
      END;

      BEGIN
      --buscar grupo economico
         SELECT a.cod_gru_economico
           INTO v_cod_grupo
           FROM ge_clientes a
          WHERE a.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_cod_grupo := null;
      END;
      v_cli_judicial := fu_ver_cli_judicial(p_cod_persona);
      /*BEGIN -- comentado 17-10-13 V.O. se utlizará el causal 279
      --buscar si es cliente judicial
         SELECT 2
           INTO v_cli_judicial
           FROM ge_cuentas g, ge_cta_clientes cli
          WHERE g.nro_cuenta = cli.nro_cuenta
            AND cli.cod_modulo in (4, 5, 6, 15)
            AND cli.cod_persona = p_cod_persona
            AND en_juicio = 'S';
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_cli_judicial := null;
      END;*/
      --buscar deuda total del grupo si corresponde
      IF v_cod_grupo IS NOT NULL THEN
         SELECT a.Tot_Deu_Real
           INTO v_tot_deu_real
           FROM ge_gru_economicos a
          WHERE a.cod_gru_economico = v_cod_grupo;

      END IF;

      IF nvl(v_ope_vencida,0) = 3 then
         v_tip_agrupacion := 3;
      ELSIF nvl(v_tot_deu_real,0) > nvl(v_max_deu_grupo,0) then
         v_tip_agrupacion := 0;
      ELSIF nvl(v_cli_judicial,'N') = 'S' then
         v_tip_agrupacion := 2;
      ELSE

        v_mto_limite         := fup_obt_mto_lin_aprobada(p_cod_persona, v_cod_mon_local);
        v_mto_ope_especifica := fug_obt_tot_ope_especifica(p_cod_persona, v_cod_mon_local);
        v_tot_riesgo         := nvl(v_mto_limite, 0) + nvl(v_mto_ope_especifica, 0);

        IF nvl(v_tot_riesgo, 0) >= v_cli_tot_riesgo THEN
           v_tip_agrupacion := 0;
        ELSE
           v_tip_agrupacion := 1;
        END IF;
       END IF;
       RETURN v_tip_agrupacion;
   END fu_obt_tip_gru_cob;

   /** Actualiza el Tipo de Agrupación para envios de datos a tercerización de Cobranza (TIP_GRU_COBRANZA) de la tabla GE_CLIENTES. **/
   PROCEDURE pr_act_tip_gru_cob IS
      /** Actualiza tip_gru_cobranza del cliente. **/
      v_tip_agrupacion VARCHAR2(1) := NULL;
      v_persona ba_personas.cod_persona%type;
      CURSOR c_clientes IS
         /*SELECT DISTINCT t.cod_persona, l.tip_gru_cobranza
           FROM ge_cuentas c, ge_cta_clientes t, ge_clientes l
          WHERE c.cod_modulo IN (4, 5, 6, 15)
            AND c.nro_cuenta = t.nro_cuenta
            AND l.cod_persona = t.cod_persona
            AND t.relacion = 'P';*/
         --> 22/08/2013-DI-MB: Por Solicitud vía Jira: CROREC-8
         SELECT DISTINCT t.cod_persona, l.tip_gru_cobranza
           FROM ge_cuentas c, ge_cta_clientes t, ge_clientes l, ge_est_cuentas a
          WHERE c.cod_modulo  IN (4, 5, 6, 15)
            AND c.nro_cuenta  = t.nro_cuenta
            AND l.cod_persona = t.cod_persona
            AND t.relacion    = 'P'
            and c.cod_modulo  = a.cod_modulo
            and c.cod_modalidad = a.cod_modalidad
            and c.estado        = a.estado
            and a.activo        = 'S';
   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
      FOR cli IN c_clientes LOOP
         v_tip_agrupacion := fu_obt_tip_gru_cob(cli.cod_persona);
         IF nvl(cli.tip_gru_cobranza, 'x') <> v_tip_agrupacion THEN
            BEGIN
               UPDATE ge_clientes
                  SET tip_gru_cobranza = v_tip_agrupacion
                WHERE cod_persona = cli.cod_persona;
            EXCEPTION
               WHEN OTHERS THEN
                  IF SQLCODE <= -20000 THEN
                     RAISE;
                  ELSE
                     raise_application_error(-20442,
                                             'No se pudo actualizar el tipo de cobranza del cliente ' ||
                                              cli.cod_persona || ': ' || SQLERRM);
                  END IF;
            END;
         END IF;
         v_persona := cli.cod_persona;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20472,
                                    'Error al Actualizar tip_gru_cobranza del cliente; '||v_persona || SQLERRM);
         END IF;
   END pr_act_tip_gru_cob;
   /*Genera los archivos txt a partir de las consultas dinámicas.*/
   PROCEDURE pr_exp_consultas
   IS
      v_fec_actual DATE := fuo_fec_strategy;

      CURSOR c_consultas IS
        SELECT b.cod_consulta, b.det_sql, b.filtros
          FROM ba_cod_referencias t, ba_consultas b
         WHERE t.dominio = 'RS_COD_CONSULTAS'
           AND b.cod_consulta = t.significado
           AND b.cod_consulta != 'CD_RS_SCOR'
         ORDER BY to_number(val_minimo);
      CURSOR c_tip_cambio IS
      -- Cotizaciones
      SELECT a.cod_moneda, TRIM(to_char(a.val_conversion,'99999D99')) valor
        FROM ge_cotizaciones a
       WHERE fecha  = (SELECT MAX(fecha)
                         FROM ge_cotizaciones
                        WHERE cod_moneda = a.cod_moneda
                          AND fecha <= v_fec_actual);
      --
      v_filtros   ba_consultas.filtros%type := '';
      v_consulta  ba_consultas.filtros%type := '';
      v_order     ba_consultas.filtros%type := '';
      v_pos       number;
      --
      v_ref_cursor t_archivo_tab;
      v_filas      NUMBER;
      v_error      VARCHAR2(4000);

      v_cod_ente   ge_entes.cod_ente%TYPE := fug_obt_pardinamico('COD_ENT_REC_STRATEGY');
      v_directorio VARCHAR2(100) := fug_obt_parentes(v_cod_ente, 'DIR_ORACLE');
      v_archivo    utl_file.file_type;
      v_nom_archivo varchar2(60);
      v_sentencia  VARCHAR2(4000);
      v_fec_proceso varchar2(10) default to_char(v_fec_actual,'YYYYMMDD');

   BEGIN
      For i in c_consultas loop
         v_filtros := '';
         v_order   := '';
         v_pos := instr(upper(i.det_sql), 'ORDER BY',1);
         if v_pos > 0 then
            v_filtros := substr(i.det_sql, 1, v_pos -1);
            v_order   := substr(i.det_sql, v_pos);
         end if;
         --
         if instr(upper(i.det_sql), 'WHERE',1) > 0 then
            v_filtros := v_filtros || ' AND ';
         else
            v_filtros := v_filtros || ' WHERE ';
         end if;
         v_filtros := null;
         --
         update ba_consultas
            set filtros = v_filtros
          where cod_consulta = i.cod_consulta;
      End loop;

     -- Creación de Interfaz de Arranque
     v_nom_archivo := 'ARRANQUE.TXT';
     v_archivo     := pag_arc.fu_arc_abrir(v_directorio,v_nom_archivo, 'w');
     pag_arc.pr_arc_escribir(v_fec_proceso, v_archivo);
     pag_arc.pr_arc_cerrar(v_archivo);
     -- Creación de archivo tipo de cambio
     v_nom_archivo := 'TCAMBIO'||v_fec_proceso||'.TXT';
     v_archivo     := pag_arc.fu_arc_abrir(v_directorio,v_nom_archivo, 'w');
     for k in c_tip_cambio loop
       pag_arc.pr_arc_escribir(k.cod_moneda||'|'||k.valor, v_archivo);
     end loop;
     pag_arc.pr_arc_cerrar(v_archivo);
     -- Creación de los archivos de consultas dinámicas
     FOR i IN c_consultas LOOP
         v_order   := '';
         v_pos := instr(upper(i.det_sql), 'ORDER BY',1);
         --
         v_consulta := i.det_sql;
/*         if v_pos > 0 then
         \* v_consulta := substr(i.det_sql, 1, v_pos -1);
            v_order    := substr(i.det_sql, v_pos);*\
            v_consulta := ''; -- La consulta completa esta en el i.filtros cuando contiene ORDER BY
         else
            v_consulta := i.det_sql;
         end if;*/
         v_nom_archivo := substr(i.cod_consulta,7)||v_fec_proceso||'.TXT';

         v_archivo   := pag_arc.fu_arc_abrir(v_directorio,v_nom_archivo, 'w');
         v_sentencia := v_consulta || chr(13) || i.filtros;
         v_error := null;
         --sql_util.ejecute_consulta(v_sentencia, 1, v_filas, v_ref_cursor, v_error);
         pr_eje_consulta(v_sentencia, 1, v_filas, v_ref_cursor, v_error);
         --
         if v_error is not null then
           pag_arc.pr_arc_escribir(v_error, v_archivo);
         else
           FOR j IN 1 .. v_filas LOOP
              pag_arc.pr_arc_escribir(v_ref_cursor(j).columna1, v_archivo);
           END LOOP;
         end if;
         pag_arc.pr_arc_cerrar(v_archivo);
      END LOOP;

   END pr_exp_consultas;

   procedure pr_eje_consulta(p_sql varchar2,p_columnas number,p_filas in out number,p_ref_cursor in out T_archivo_tab,p_error out varchar2) is
    reg   t_array;
    v_result boolean;
    v_cursor number;
    v_rows   number(10) := 1;
    v_encabezado         varchar2(200) := 'encabezado';
    v_col_varchar2     varchar2(120);
    v_col_etiqueta       varchar2(200);
    v_col_informacion    varchar2(200);
    v_col_fec_vento    varchar2(200);
    v_cont            number(5) := 1;
    procedure pr_ini_estructura(p_estructura in out t_array,p_inicio number) is
    begin
     for i in p_inicio..20 loop
       p_estructura(i) := null;
      end loop;
    end ;
  begin
    p_error := null;
    p_filas := 0;
    if p_columnas > 20 then
      p_error := 'El maximo nzmero de columnas para la consulta es 20';
      return;
    end if;
    if p_sql is not null and p_columnas > 0 then
    v_result := dbms_sql.is_open(v_cursor);
    if not v_result then
      v_cursor     := dbms_sql.open_cursor;
      v_result := dbms_sql.is_open(v_cursor);
      if v_result then
         dbms_sql.parse(v_cursor,p_sql,dbms_sql.native); --1 = NATIVE, 2 = V7 Y 0 = V6
         --Variables en el cursors
         for i in 1..p_columnas loop
            dbms_sql.define_column(v_cursor,i,v_col_varchar2,1000);
         end loop;
         v_rows := dbms_sql.execute(v_cursor);
      end if;
    end if;
      v_rows :=  dbms_sql.fetch_rows(v_cursor);
      loop exit when v_rows = 0;
        p_filas := p_filas + 1;
        for i in 1..p_columnas loop
         dbms_sql.column_value(v_cursor,i,reg(i));
        end loop;
       pr_ini_estructura(reg,p_columnas+1);
       p_ref_cursor(p_filas).columna1 := reg(1);
       p_ref_cursor(p_filas).columna2 := reg(2);
       p_ref_cursor(p_filas).columna3 := reg(3);
       p_ref_cursor(p_filas).columna4 := reg(4);
       p_ref_cursor(p_filas).columna5 := reg(5);
       p_ref_cursor(p_filas).columna6 := reg(6);
       p_ref_cursor(p_filas).columna7 := reg(7);
       p_ref_cursor(p_filas).columna8 := reg(8);
       p_ref_cursor(p_filas).columna9 := reg(9);
       p_ref_cursor(p_filas).columna10 := reg(10);
       p_ref_cursor(p_filas).columna11 := reg(11);
       p_ref_cursor(p_filas).columna12 := reg(12);
       p_ref_cursor(p_filas).columna13 := reg(13);
       p_ref_cursor(p_filas).columna14 := reg(14);
       p_ref_cursor(p_filas).columna15 := reg(15);
       p_ref_cursor(p_filas).columna16 := reg(16);
       p_ref_cursor(p_filas).columna17 := reg(17);
       p_ref_cursor(p_filas).columna18 := reg(18);
       p_ref_cursor(p_filas).columna19 := reg(19);
       p_ref_cursor(p_filas).columna20 := reg(20);
        v_rows :=  dbms_sql.fetch_rows(v_cursor);
      end loop;
     dbms_sql.close_cursor(v_cursor);
    end if;
   exception
    when others then
      dbms_sql.close_cursor(v_cursor); --- Cerrar cursor
      p_error := 'PR_EJE_CONSULTA '||sqlerrm;
   end pr_eje_consulta;
   PROCEDURE pr_gen_arc_recovery is
   BEGIN
     -- Generacion datos
     PAO_COB.PR_GEN_PREVENTIVAS;
     -- Generacion de archivos
     PAO_COB.PR_EXP_CONSULTAS;

   END pr_gen_arc_recovery;
END pao_cob;
/

