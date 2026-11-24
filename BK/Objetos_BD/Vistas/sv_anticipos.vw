create or replace force view it.sv_anticipos as
select cl.cod_persona,
        fug_obt_nom_cuenta(pr.nro_cuenta) nombre,
        cu.fec_vencimiento,
        cu.nro_cuota,
        nvl(cu.sal_capital,0)+nvl(cu.sal_interes,0)+nvl(cu.sal_int_documentado,0) monto,
        pr.cod_oficina,
        pr.fec_inicio,
        pr.nro_solicitud,
        pr.val_tasa,
        lpad(cl.cod_persona,6,'0')||','|| --NRO_RIESGO
        to_char(cu.fec_vencimiento,'yyyymmdd')||','|| --FEC_VENCIMIENTO
        lpad(cu.nro_cuota,5,'0')||','|| --NRO_DOCUMENTO
        lpad(nvl(cu.sal_capital,0)+nvl(cu.sal_interes,0)+nvl(cu.sal_int_documentado,0),8,'0')||','|| --MONTO
        rpad(' ',15,' ')||','|| --PRI_APELLIDO
        rpad(' ',40,' ')||','|| --NOM_SIGLA
        rpad(' ',12,' ')||','|| --CONGRU
        lpad(pr.cod_oficina,3,'0')||','|| --COD_OFICINA
        --to_char(pr.fec_inicio,'yyyymmdd')||','|| --FEC_INICIO
        to_char(pr.fec_inicio,'ddmmyy')||','|| --FEC_INICIO
        lpad(pr.nro_solicitud,8,'0')||','|| --PROPUESTA
        lpad(pr.val_tasa,2,'0') registro --COD_TASA
   from ge_cta_clientes cl, pr_cta_prestamos pr, pr_cuotas cu
  where pr.nro_cuenta = cu.nro_cuenta
    and pr.nro_cuenta = cl.nro_cuenta
    and pr.cod_modalidad not in (608) --- no incluir asociaciones ni descuentos documentos
    and nvl(fug_obt_pardinamico('MAD_ANTICIPOS',pr.cod_modulo,pr.cod_modalidad),'N') = 'S' --Solo Anticipos al Personal
    and cl.relacion        = 'P'  --- Cliente principal
    and pr.estado          <> 'N' --- Préstamos no cancelados
    and (nvl(cu.sal_capital,0) <> 0 or nvl(cu.sal_interes,0) <> 0) -- Cuotas con saldo
    and nro_cuota > 0
    and cu.estado  <> 'N' --- Cuotas no canceladas
  order by 1
;

