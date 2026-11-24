CREATE OR REPLACE PROCEDURE IT.PRP_INS_DAT_FOGAPY is

v_lugar                varchar2(100) :=null;--indica lugar del error
v_cuenta               varchar2(100) :=null;--indica cuenta del error
v_fec_gen_fogapy       number (2) := fug_obt_pardinamico('FEC_GEN_FOGAPY');--par dinamico que define desde que fecha 'DD' procesar
v_dia_fec              number (2) := null;--variable que contiene la fecha 'DD' del dia de proceso
v_ultimo_dia_mes       date := null;--fin de mes
v_ultimo_dia_mes_habil date := null;--ultimo dia habil del mes
v_fec_actual           date := null;--dia en que se corre el proceso
v_primer_dia_sgte_mes  date := null;--inicio del sgte mes
v_ultimo_dia_sgte_mes  date := null;--ultimo dia del sgte mes

  cursor fogapy_diario is
    select p.cod_moneda,
        c.cod_persona,
       (SELECT decode(pe.cod_tip_documento,1, pe.nro_documento||'-'||replace(fue_obt_ruc_dig_verificador(trim(pe.nro_documento)),'-',''),
                      pe.nro_documento)
        FROM BA_PERSONAS Pe WHERE C.COD_PERSONA = Pe.COD_PERSONA)  nro_documento,
        p.nro_cuenta,
        pg.nro_garantia,
        g.nro_referencia,
        fue_obt_nom_persona(c.cod_persona) nom_completo,
        p.fec_inicio,
        p.mto_capital capital,
        p.fec_vencimiento,
        (Select NVL(SUM(PX.SAL_CAPITAL),0)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.ESTADO <>'N') SAL_CAPITAL,
           (Select min(PX.FEC_VENCIMIENTO)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.FEC_VENCIMIENTO > v_ultimo_dia_mes) FEC_VEN_PROX_CUO_CAPITAL,--fin de mes
           (Select NVL(SUM(PX.SAL_CAPITAL),0)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.ESTADO <>'N'
            AND    PX.FEC_VENCIMIENTO > v_ultimo_dia_sgte_mes)SIG_SAL_CAPITAL,--ultimo dia del sgte mes
           (Select NVL(COUNT(PX.NRO_CUOTA),0)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL = 0
            AND    PX.ESTADO ='N')CAN_CUO_PAGADAS,
           (Select CASE
                   WHEN (min(PX.FEC_VENCIMIENTO) IS NULL) THEN
                     0
                   ELSE
                     (v_fec_actual - min(PX.FEC_VENCIMIENTO) ) --fecha actual
                   END DIAS_ATRASO
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.ESTADO <>'N'
            AND    PX.FEC_VENCIMIENTO < v_fec_actual)DIA_ATRASO,--fecha actual
           (Select NVL(COUNT(PX.NRO_CUOTA),0)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.ESTADO <>'N'
            AND    PX.FEC_VENCIMIENTO < v_fec_actual) CAN_CUO_ATRASADAS--fecha actual
        from pr_cta_prestamos p, ge_cta_clientes c, pr_garantias g, pr_cta_garantias pg
        where p.nro_cuenta = c.nro_cuenta
        and c.relacion ='P'
        and p.estado <> 'N' -- no cancelados
        and c.cod_persona = g.cod_persona
        and g.nro_garantia = pg.nro_garantia
        and g.cod_persona = pg.cod_persona
        and p.nro_cuenta = pg.nro_cuenta
        and p.cod_modalidad in (645,646)
        and g.cod_garantia = 28
        and pg.nro_garantia = (select xs.nro_garantia from pr_cta_garantias xs
                               where xs.nro_cuenta = p.nro_cuenta
                               and xs.cod_garantia = 28
                               and xs.fec_insercion = (select min(xss.fec_insercion) from pr_cta_garantias xss
                                                       where xss.nro_cuenta = p.nro_cuenta
                                                       and xss.cod_garantia = 28));

  cursor fogapy_finmes is
    select p.cod_moneda,
        c.cod_persona,
       (SELECT decode(pe.cod_tip_documento,1, pe.nro_documento||'-'||replace(fue_obt_ruc_dig_verificador(trim(pe.nro_documento)),'-',''),
                      pe.nro_documento)
        FROM BA_PERSONAS Pe WHERE C.COD_PERSONA = Pe.COD_PERSONA)  nro_documento,
        p.nro_cuenta,
        pg.nro_garantia,
        g.nro_referencia,
        fue_obt_nom_persona(c.cod_persona) nom_completo,
        p.fec_inicio,
        p.mto_capital capital,
        p.fec_vencimiento,
        (Select NVL(SUM(PX.SAL_CAPITAL),0)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.ESTADO <>'N') SAL_CAPITAL,
           (Select min(PX.FEC_VENCIMIENTO)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.FEC_VENCIMIENTO > v_ultimo_dia_mes) FEC_VEN_PROX_CUO_CAPITAL,--fin de mes
           (Select NVL(SUM(PX.SAL_CAPITAL),0)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.ESTADO <>'N'
            AND    PX.FEC_VENCIMIENTO > v_ultimo_dia_sgte_mes)SIG_SAL_CAPITAL,--ultimo dia del sgte mes
           (Select NVL(COUNT(PX.NRO_CUOTA),0)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL = 0
            AND    PX.ESTADO ='N')CAN_CUO_PAGADAS,
           (Select CASE
                   WHEN (min(PX.FEC_VENCIMIENTO) IS NULL) THEN
                     0
                   ELSE
                     (v_ultimo_dia_mes - min(PX.FEC_VENCIMIENTO) ) --fin de mes
                   END DIAS_ATRASO
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.ESTADO <>'N'
            AND    PX.FEC_VENCIMIENTO < v_primer_dia_sgte_mes)DIA_ATRASO,--inicio del sgte mes
           (Select NVL(COUNT(PX.NRO_CUOTA),0)
            From   PR_CUOTAS PX
            WHERE  PX.NRO_CUENTA = P.NRO_CUENTA
            AND    PX.SAL_CAPITAL <> 0
            AND    PX.ESTADO <>'N'
            AND    PX.FEC_VENCIMIENTO < v_ultimo_dia_mes) CAN_CUO_ATRASADAS--fin de mes
        from pr_cta_prestamos p, ge_cta_clientes c, pr_garantias g, pr_cta_garantias pg
        where p.nro_cuenta = c.nro_cuenta
        and c.relacion ='P'
        and p.estado <> 'N' -- no cancelados
        and c.cod_persona = g.cod_persona
        and g.nro_garantia = pg.nro_garantia
        and g.cod_persona = pg.cod_persona
        and p.nro_cuenta = pg.nro_cuenta
        and p.cod_modalidad in (645,646)
        and g.cod_garantia = 28
        and pg.nro_garantia = (select xs.nro_garantia from pr_cta_garantias xs
                               where xs.nro_cuenta = p.nro_cuenta
                               and xs.cod_garantia = 28
                               and xs.fec_insercion = (select min(xss.fec_insercion) from pr_cta_garantias xss
                                                       where xss.nro_cuenta = p.nro_cuenta
                                                       and xss.cod_garantia = 28));

BEGIN

--Carga las variables de las fechas
v_lugar := 'Variables';
select x.ult_dia_mes into v_ultimo_dia_mes from ge_calendarios x where x.cod_modulo=1;
select x.ult_dia_mes_habil into v_ultimo_dia_mes_habil from ge_calendarios x where x.cod_modulo=1;
select x.fec_actual into v_fec_actual from ge_calendarios x where x.cod_modulo=1;
select EXTRACT(DAY FROM (v_fec_actual)) into v_dia_fec FROM DUAL;
select add_months(x.pri_dia_mes,1) into v_primer_dia_sgte_mes from ge_calendarios x where x.cod_modulo=1;
select last_day(add_months(trunc(x.ult_dia_mes),1)) into v_ultimo_dia_sgte_mes from ge_calendarios x
                                                                               where x.cod_modulo=1;

--Carga la tabla PR_RES_FOGAPY
v_lugar := 'Insertando';
 If v_fec_actual = v_ultimo_dia_mes_habil then
  For a in fogapy_finmes loop
   v_cuenta := a.nro_cuenta;
      INSERT INTO PR_RES_FOGAPY (FEC_PROCESO, Nro_Cuenta, Cod_moneda, Cod_persona, Nro_documento, Nom_completo,
                                 Nro_Garantia, Nro_Referencia, Fec_inicio, Fec_Vencimiento, Capital, SAL_CAPITAL,
                                 SIG_SAL_CAPITAL, FEC_VEN_PROX_CUO_CAPITAL, CAN_CUO_PAGADAS, CAN_CUO_ATRASADAS,
                                 DIA_ATRASO)
           VALUES (v_fec_actual, a.nro_cuenta, a.cod_moneda, a.cod_persona, a.nro_documento, a.nom_completo,
                   a.nro_garantia, a.nro_referencia, a.fec_inicio, a.fec_vencimiento, a.capital, a.SAL_CAPITAL,
                   a.SIG_SAL_CAPITAL, a.FEC_VEN_PROX_CUO_CAPITAL, a.CAN_CUO_PAGADAS, a.CAN_CUO_ATRASADAS,
                   a.DIA_ATRASO);
  end loop;
 Elsif v_fec_actual < v_ultimo_dia_mes_habil and v_dia_fec >= v_fec_gen_fogapy then
  For a in fogapy_diario loop
   v_cuenta := a.nro_cuenta;
      INSERT INTO PR_RES_FOGAPY (FEC_PROCESO, Nro_Cuenta, Cod_moneda, Cod_persona, Nro_documento, Nom_completo,
                                 Nro_Garantia, Nro_Referencia, Fec_inicio, Fec_Vencimiento, Capital, SAL_CAPITAL,
                                 SIG_SAL_CAPITAL, FEC_VEN_PROX_CUO_CAPITAL, CAN_CUO_PAGADAS, CAN_CUO_ATRASADAS,
                                 DIA_ATRASO)
           VALUES (v_fec_actual, a.nro_cuenta, a.cod_moneda, a.cod_persona, a.nro_documento, a.nom_completo,
                   a.nro_garantia, a.nro_referencia, a.fec_inicio, a.fec_vencimiento, a.capital, a.SAL_CAPITAL,
                   a.SIG_SAL_CAPITAL, a.FEC_VEN_PROX_CUO_CAPITAL, a.CAN_CUO_PAGADAS, a.CAN_CUO_ATRASADAS,
                   a.DIA_ATRASO);
  end loop;
 End if;
exception
  when others then
    raise_application_error(-20000,'Error en PRP_INS_DAT_FOGAPY: '||v_lugar||' '||v_cuenta||' '||sqlerrm);
End PRP_INS_DAT_FOGAPY;
/

