CREATE OR REPLACE TYPE IT."TYP_INFECONOMICOS"                                          IS OBJECT
   (
      sue_fijo           number,
      sue_variable       number,
      ing_independiente  number,
      ing_venta          number,
      alq_cobrado        number,
      int_ahorro         number,
      ren_accion         number,
      jub_pencion        number,
      gas_familiar       number,
      cuo_consumo        number,
      cuo_tarjeta        number,
      cuo_hipoteca       number,
      alq_pagado         number,
      otr_cuota          number,
      CONSTRUCTOR FUNCTION TYP_INFECONOMICOS RETURN SELF AS RESULT
   )
/

