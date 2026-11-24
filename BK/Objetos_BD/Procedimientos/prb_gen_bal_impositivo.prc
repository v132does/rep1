CREATE OR REPLACE PROCEDURE IT.PRB_GEN_BAL_IMPOSITIVO
(p_fec_desde in date,--
 p_fec_hasta in date)
 IS
v_fec_desde date;
v_fec_hasta date;

    --
procedure lp_acu_importe is
-- variables cursor maestro
nrorden  number(07);
cdcuent  varchar2(15);
-- variables cursor movimi0, movimi1, movimi2, movimi3
immovdb  number(22);
immovcr  number(22);
-- otras variables auxiliares
totdebi  number(22);
totcred  number(22);
slinici  number(22);
-- variables auxiliares
contador number(07) := 0;
porcenta number(03) := 0;
------------ define maestro -------
cursor maestro is
   select nro_orden, cod_rubro
     from cb_rub_bal_impositivo
    where cod_rubro is not null
    order by nro_orden, cod_rubro;
------------ define movimi1 --------
cursor movimi1 is
  select sum(decode(b.tip_movimiento,'D',nvl(b.mto_mon_local,0),0)),
         sum(decode(b.tip_movimiento,'C',nvl(b.mto_mon_local,0),0))
    from cb_asientos_his a, cb_asientos_det_his b
   where a.cod_oficina = b.cod_oficina
     and a.nro_asiento= b.nro_asiento
     and a.fecha = b.fecha
     and trunc(a.fecha) between v_fec_desde and v_fec_hasta
     and a.confirmado = 'S'
     and a.actualizado = 'S'
     and b.actualizado = 'S'
     and substr(b.cod_rubro,1,2) = substr(cdcuent,1,2)
     and substr(b.cod_rubro,4,2) = substr(cdcuent,4,2)
     and b.descripcion not in ('ASIENTO DE CIERRE')
     and not exists (select 0 from cb_rub_bal_impositivo
                      where cod_rubro = b.cod_rubro);

begin
if maestro%isopen then
   close maestro;
end if;
-- leer movimien
open maestro;
loop
   fetch maestro into nrorden, cdcuent;
   exit when maestro%notfound;
   if substr(cdcuent,6,10) = '0000000000' then
      if movimi1%isopen then
         close movimi1;
      end if;
      open movimi1;
      loop
         fetch movimi1 into immovdb, immovcr;
         exit when movimi1%notfound;
         -- inserta detalles de cuentas asentables --
         insert into cb_rub_bal_impositivo_det
         select cdcuent, b.cod_rubro,
                sum(decode(b.tip_movimiento,'D', nvl(b.mto_mon_local,0),0)),
                sum(decode(b.tip_movimiento,'C', nvl(b.mto_mon_local,0),0)),
                user, sysdate, user, sysdate
           from cb_asientos_his a, cb_asientos_det_his b
          where a.cod_oficina = b.cod_oficina
           and a.nro_asiento= b.nro_asiento
           and a.fecha = b.fecha
           and trunc(a.fecha) between v_fec_desde and v_fec_hasta
           and a.confirmado = 'S'
           and a.actualizado = 'S'
           and b.actualizado = 'S'
           and substr(b.cod_rubro,1,2) = substr(cdcuent,1,2)
           and substr(b.cod_rubro,4,2) = substr(cdcuent,4,2)
           and not exists (select 0 from cb_rub_bal_impositivo
                            where cod_rubro = b.cod_rubro)
          group by cdcuent, b.cod_rubro;
         insert into cb_rub_bal_impositivo_det
         select cdcuent, cod_rubro, 0, 0, user, sysdate, user, sysdate
           from cb_sal_consolidados_his
          where cod_rubro is not null
            and ano = to_char(v_fec_desde,'YYYY')
            and mes = to_number(to_char(v_fec_desde,'MM'))
            and nvl(sal_ini_mes_mon_local,0) <> 0
            and substr(cod_rubro,14,2) <> '00'
            and substr(cod_rubro,1,2) = substr(cdcuent,1,2)
            and substr(cod_rubro,4,2) = substr(cdcuent,4,2)
            and cod_rubro not in (select b.cod_rubro
                                    from cb_rub_bal_impositivo_det b
                                   where b.cod_rub_padre = cdcuent
                                     and b.cod_rubro = cod_rubro)
            and not exists (select 0
                              from cb_rub_bal_impositivo
                             where cod_rubro = cod_rubro);
          --------------------------------------------
      end loop;
    elsif substr(cdcuent,14,2) <> '00' and
          substr(cdcuent,6,10) <> '9999999999' then
      select
         sum(decode(b.tip_movimiento,'D',nvl(b.mto_mon_local,0),0)),
         sum(decode(b.tip_movimiento,'C',nvl(b.mto_mon_local,0),0))
        into immovdb, immovcr
        from cb_asientos_his a, cb_asientos_det_his b
       where  a.cod_oficina = b.cod_oficina
         and a.nro_asiento= b.nro_asiento
         and a.fecha = b.fecha
         and trunc(a.fecha) between v_fec_desde and v_fec_hasta
         and a.confirmado = 'S'
         and a.actualizado = 'S'
         and b.actualizado = 'S'
         and b.cod_rubro = cdcuent
         and b.descripcion not in ('ASIENTO DE CIERRE');
    end if;
    -- obtiene el saldo inicial del cb_sal_consolidados_his --
    begin
         select sal_ini_mes_mon_local
           into slinici
           from cb_sal_consolidados_his
          where cod_rubro = cdcuent
            and ano = to_char(v_fec_desde,'YYYY')
            and mes = to_number(to_char(v_fec_desde,'MM'));
    exception
         when no_data_found then
           slinici := 0;
           --si no existe inserta en cb_bal_impositivo
    end;
    -- actualiza el archivo cb_bal_impositivo totales de bal. impositivo --
    if slinici < 0 then
            update cb_bal_impositivo
               set sum_credito = nvl(sum_credito,0) +
                                abs(slinici) + nvl(immovcr,0),
                   sum_debito = nvl(sum_debito,0) + nvl(immovdb,0)
             where nro_orden = nrorden;
     end if;
     if slinici > 0 then
            update cb_bal_impositivo
               set sum_debito = nvl(sum_debito,0) +
                                nvl(slinici,0) + nvl(immovdb,0),
                   sum_credito = nvl(sum_credito,0) + nvl(immovcr,0)
             where nro_orden = nrorden;
     end if;
     if slinici = 0 then
            update cb_bal_impositivo
               set sum_debito  = nvl(sum_debito,0) + nvl(immovdb,0),
                   sum_credito = nvl(sum_credito,0) + nvl(immovcr,0)
             where nro_orden = nrorden;
     end if;
     -- pone en nulo las variables auxiliares                   --
     slinici  := 0;
     immovdb  := 0;
     immovcr  := 0;
end loop;
close maestro;
end;

PROCEDURE lp_act_UTI_EJERCICIO IS
WW_GANANCIA NUMBER(22,2);
WW_PERDIDA  NUMBER(22,2);
WW_UTILIDAD NUMBER(22,2);
BEGIN
  SELECT NVL(SAL_MON_LOC_ANT,0)+NVL(deb_mon_local,0)-NVL(cre_mon_local,0)
    INTO WW_GANANCIA
    FROM cb_sal_consolidados_his
   WHERE cod_rubro = '600000000000000'
     AND ano = TO_CHAR(v_fec_hasta,'YYYY')
     AND mes = TO_CHAR(v_fec_hasta,'MM');
  SELECT NVL(SAL_MON_LOC_ANT,0)+NVL(deb_mon_local,0)-NVL(cre_mon_local,0)
    INTO WW_PERDIDA
    FROM cb_sal_consolidados_his
   WHERE cod_rubro = '700000000000000'
     AND ano = TO_CHAR(v_fec_hasta,'YYYY')
     AND mes = TO_CHAR(v_fec_hasta,'MM');
  WW_UTILIDAD := (NVL(WW_GANANCIA,0)*-1) - NVL(WW_PERDIDA,0);
  IF WW_UTILIDAD > 0 THEN  /* es utilidad */
     UPDATE cb_bal_impositivo
        SET sum_debito = NVL(WW_UTILIDAD,0)
      WHERE nro_orden = 74050;
     UPDATE cb_bal_impositivo
        SET sum_credito = NVL(WW_UTILIDAD,0)
      WHERE nro_orden = 31060;
  ELSE /* es un perdida */
     UPDATE cb_bal_impositivo
        SET sum_credito = ABS(NVL(WW_UTILIDAD,0))
      WHERE nro_orden = 74050;
     UPDATE cb_bal_impositivo
        SET sum_debito = ABS(NVL(WW_UTILIDAD,0))
      WHERE nro_orden = 31060;
  END IF;
EXCEPTION
   WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000,'Lee utilidad del Ejercicio'||sqlerrm);
END;

PROCEDURE lp_ACT_SALDOS IS
---- VARIABLES CURSOR MAESTRO
NRORDEN          NUMBER(07);
TPCUENT        VARCHAR2(01);
TTDEBIT          NUMBER(22);
TTCREDI          NUMBER(22);
---- OTRAS VARIABLES UTILIZADAS
DIFEREN          NUMBER(22);
SLDEUDO          NUMBER(22);
SLACREE          NUMBER(22);
------------------------- DEFINE MAESTRO ------------------------------
--tabla precargada con el formato de Hacienda
CURSOR MAESTRO IS
   SELECT cb_bal_impositivo.nro_orden, cb_bal_impositivo.tip_rubro,
          cb_bal_impositivo.sum_debito, cb_bal_impositivo.sum_credito
     FROM cb_bal_impositivo
    ORDER BY cb_bal_impositivo.nro_orden;

BEGIN
IF MAESTRO%ISOPEN THEN
   CLOSE MAESTRO;
END IF;
-- LEER MAESTRO
OPEN MAESTRO;
LOOP
   FETCH MAESTRO INTO NRORDEN, TPCUENT, TTDEBIT, TTCREDI;
      EXIT WHEN MAESTRO%NOTFOUND;
      DIFEREN := NVL(TTDEBIT,0) - NVL(TTCREDI,0);
      IF NVL(DIFEREN,0) > 0 THEN
         SLDEUDO := DIFEREN;
         SLACREE := 0;
      END IF;
      IF NVL(DIFEREN,0) < 0 THEN
         SLDEUDO := 0;
         SLACREE := ABS(DIFEREN);
      END IF;
      IF NVL(DIFEREN,0) = 0 THEN
         SLDEUDO := 0;
         SLACREE := 0;
      END IF;
      IF TPCUENT = 'A' THEN
         IF NVL(SLDEUDO,0) <> 0 THEN
            UPDATE cb_bal_impositivo
               SET sal_deudor = SLDEUDO,
                   sal_acreedor = SLACREE,
                   inv_activo = SLDEUDO
             WHERE nro_orden = NRORDEN;
         END IF;
         IF NVL(SLACREE,0) <> 0 THEN
            UPDATE cb_bal_impositivo
               SET sal_deudor = SLDEUDO,
                   sal_acreedor = SLACREE,
                   inv_activo = SLACREE * -1
             WHERE nro_orden = NRORDEN;
         END IF;
      END IF;
      IF TPCUENT = 'P' THEN
         IF NVL(SLDEUDO,0) <> 0 THEN
            UPDATE cb_bal_impositivo
               SET sal_deudor = SLDEUDO,
                   sal_acreedor = SLACREE,
                   inv_pasivo = SLDEUDO * -1
             WHERE nro_orden = NRORDEN;
         END IF;
         IF NVL(SLACREE,0) <> 0 THEN
            UPDATE cb_bal_impositivo
               SET sal_deudor = SLDEUDO,
                   sal_acreedor = SLACREE,
                   inv_pasivo = SLACREE
             WHERE nro_orden = NRORDEN;
         END IF;
      END IF;
      IF TPCUENT = 'R' THEN
         UPDATE cb_bal_impositivo
            SET sal_deudor = SLDEUDO,
                res_perdida = SLDEUDO,
                sal_acreedor = SLACREE,
                res_ganancia = SLACREE
          WHERE nro_orden = NRORDEN;
      END IF;
      -- PONE EN NULO LAS VARIABLES AUXILIARES --
      DIFEREN := 0;
      SLDEUDO := 0;
      SLACREE := 0;
END LOOP;
CLOSE MAESTRO;
END;
-- Inicio del proceso principal de generación de datos para el Balance Impositivo
BEGIN
   --tomar desde 01/01 del año ant al 31/12 si no recibe parámetros
   if p_fec_desde is null or p_fec_hasta is null then
      v_fec_desde := to_date('01/01/'||to_char(to_number(to_char(pag_cal.FU_OBT_FEC_ACTUAL(2),'YYYY')-1)) ,'DD/MM/YYYY');
      v_fec_hasta := to_date('31/12/'||to_char(to_number(to_char(pag_cal.FU_OBT_FEC_ACTUAL(2),'YYYY')-1)) ,'DD/MM/YYYY');
   else
      v_fec_desde := p_fec_desde;
      v_fec_hasta := p_fec_hasta;
   end if;
   --acumular importes
   lp_acu_importe;
   --actualizar con utilidad/pérdida del ejercicio
   lp_act_uti_ejercicio;
   --actualizar saldos
   lp_act_saldos;
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,'Gen.Bal.Impositivo. '||sqlerrm);
      end if;
END;
/

