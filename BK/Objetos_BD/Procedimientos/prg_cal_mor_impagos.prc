CREATE OR REPLACE PROCEDURE IT.PRG_CAL_MOR_IMPAGOS
 (P_NRO_CUENTA IN VARCHAR2 DEFAULT NULL
 )
 IS
  CURSOR c1
      IS select p.cod_modulo, p.cod_modalidad, p.nro_cuenta, p.dia_atraso, c.cod_persona
           from pr_cta_prestamos p, ge_cta_clientes c, ba_personas pe
          where (p.estado not in ('N', 'I') or p.fec_cancelacion = pag_cal.G_FEC_ACTUAL)
            and p.nro_cuenta = nvl(p_nro_cuenta, p.nro_cuenta)
            and p.nro_cuenta = c.nro_cuenta
            and c.cod_persona = pe.cod_persona
            and c.relacion = 'P'
            and p.dia_atraso > 0
            --and pe.tipo = 'F'
         union all
         select t.cod_modulo, t.cod_modalidad, t.nro_cuenta, t.dia_mora, c.cod_persona
           from ta_cta_tarjetas t, ge_cta_clientes c, ba_personas pe
          where t.nro_cuenta = nvl( p_nro_cuenta, t.nro_cuenta )
            and t.dia_mora > 0
            and t.nro_cuenta = c.nro_cuenta
            and c.cod_persona = pe.cod_persona
            and c.relacion = 'P'
            --and pe.tipo = 'F'
         union all
         select t.cod_modulo, t.cod_modalidad, r.nro_cuenta,
                r.can_dias, c.cod_persona
           from cc_sobregiros_res r, cc_cta_corrientes t, ge_cta_clientes c, ba_personas pe
          where r.nro_cuenta = nvl(p_nro_cuenta, r.nro_cuenta)
            and r.nro_cuenta = t.nro_cuenta
            and r.can_dias > 0
            and t.nro_cuenta = c.nro_cuenta
            and c.cod_persona = pe.cod_persona
            and c.relacion = 'P';
            --and pe.tipo = 'F';

  v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(4);
  v_exi_dia_mor varchar2(1);
  v_can_dia_mora number;
  v_mes ge_cta_dia_mor_tmp.mes%type;
  v_ano ge_cta_dia_mor_tmp.ano%type;

BEGIN
  FOR r1 IN c1 LOOP
    if r1.dia_atraso > 0 then
        v_mes := to_char(v_fec_actual, 'MM');
        v_ano := to_char(v_fec_actual, 'YYYY');
        begin
           select 'S', dia_mora
             into v_exi_dia_mor, v_can_dia_mora
             from GE_CTA_DIA_MOR_TMP
            where nro_cuenta = r1.nro_cuenta
              and ano = v_ano
              AND mes = v_mes;
           exception
             when others then
               v_exi_dia_mor := 'N';
           end;

           if nvl(v_exi_dia_mor, 0) = 'N' then
              begin
                insert into ge_cta_dia_mor_tmp (nro_cuenta,
                                                ano,
                                                mes,
                                                cod_modulo,
                                                cod_modalidad,
                                                cod_persona,
                                                dia_mora)
                                         values (r1.nro_cuenta,
                                                 v_ano,
                                                 v_mes,
                                                 r1.cod_modulo,
                                                 r1.cod_modalidad,
                                                 r1.cod_persona,
                                                 r1.dia_atraso);
              exception
                when others then
                   null;
              end;
           else
             if nvl(r1.dia_atraso, 0) > nvl(v_can_dia_mora,0) then
               begin
                 update ge_cta_dia_mor_tmp
                    set dia_mora = r1.dia_atraso
                  where nro_cuenta = r1.nro_cuenta
                    and ano = v_ano
                    and mes = v_mes;
               exception
                 when others then
                   null;
               end;
             end if;
          end if;
        end if;

  END LOOP;
END PRG_CAL_MOR_IMPAGOS;
/

