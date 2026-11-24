create or replace view it.lv_cta_prestamos as
select
    C.NRO_CUENTA NRO_CUENTA,
    C.COD_MODALIDAD COD_MODALIDAD,
    CL.COD_PERSONA COD_PERSONA,
    PAG_GEN.FU_OBT_MON_FUERTE COD_MONEDA,
    C.ESTADO ESTADO,
    C.COD_OFICINA COD_OFICINA,
    C.TIP_RENOVACION TIP_RENOVACION,
    C.NRO_CTA_RENOVADA NRO_CTA_RENOVADA,
     /*
    case when TO_NUMBER(TO_CHAR(C.FEC_INICIO, 'yyyy')) < 1593 then to_date(to_char(C.FEC_INICIO, 'dd/mm') || '/2010', 'dd/mm/yyyy')
    else to_date(c.fec_inicio,'dd/mm/yyyy') end FEC_INICIO,
    */

    CASE WHEN FEC_INICIO <= '01/01/1900' THEN to_date(to_char('01/01/1900'), 'dd/mm/yyyy')
      ELSE to_date(to_char(FEC_INICIO, 'dd/mm/yyyy'), 'dd/mm/yyyy') END FEC_INICIO,

    CASE WHEN Fec_Vencimiento <= '01/01/1900' THEN to_date(to_char('01/01/1900'), 'dd/mm/yyyy')
      ELSE to_date(to_char(Fec_Vencimiento, 'dd/mm/yyyy'), 'dd/mm/yyyy') END Fec_Vencimiento,

    CASE WHEN FEC_CANCELACION <= '01/01/1900' THEN to_date(to_char('01/01/1900'), 'dd/mm/yyyy')
      ELSE to_date(to_char(FEC_CANCELACION, 'dd/mm/yyyy'), 'dd/mm/yyyy') END FEC_CANCELACION,

    C.COD_ORI_FONDO COD_ORI_FONDO,
    C.TIPO TIPO

  from PR_CTA_PRESTAMOS C,
       GE_CTA_CLIENTES CL
  where C.NRO_CUENTA = CL.NRO_CUENTA
  and C.ESTADO not in('S', 'X')
  and CL.RELACION = 'P';
-- Create the synonym
create or replace public synonym lv_cta_prestamos
  for IT.lv_cta_prestamos;
