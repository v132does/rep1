create or replace procedure it.prc_gen_reporte_seg_client is

  /*  -- Author  : GABRIEL.CAPO
  -- Created : 21/06/2011 12:15:26
  -- Purpose : Inserta registros en la tabla ge_riesgo_clientes, para luego poder generar un reporte,
               dicho procedimiento se ejecuta como proceso independiente */

begin

  --borra todos los registros de la tabla ge_riesgo_clientes para poder cargarlo nuevamente
  delete ge_riesgo_clientes;
  commit;

  /*-----------------------------------------------------------------------------------*/
  /*    Inserta los registros de Activo, Pasivo, Cantidad, y el tipo en la tabla       */
  /*-----------------------------------------------------------------------------------*/
  insert into ge_riesgo_clientes
    (activo, pasivo, cantidad, tipo)
    (select sum(fug_obt_activo_cliente(a.cod_persona)) as activo,
            sum(fug_obt_pasivo_cliente(a.cod_persona)) as pasivo,
            count(1),
            '1' -- PERSONAS FISICAS
       from ge_clientes a, ba_personas b
      where a.cod_persona = b.cod_persona
        and b.tipo = 'F');

  insert into ge_riesgo_clientes
    (activo, pasivo, cantidad, tipo)
    (select sum(fug_obt_activo_cliente(a.cod_persona)) as activo,
            sum(fug_obt_pasivo_cliente(a.cod_persona)) as pasivo,
            count(1),
            '2' -- PERSONAS FISICAS RESIDENTES
       from ge_clientes a, ba_personas b
      where a.cod_persona = b.cod_persona
        and b.tipo = 'F'
        and a.residente = 'S');

  insert into ge_riesgo_clientes
    (activo, pasivo, cantidad, tipo)
    (select sum(fug_obt_activo_cliente(a.cod_persona)) as activo,
            sum(fug_obt_pasivo_cliente(a.cod_persona)) as pasivo,
            count(1),
            '3' -- PERSONAS FISICAS NO RESIDENTES
       from ge_clientes a, ba_personas b
      where a.cod_persona = b.cod_persona
        and b.tipo = 'F'
        and a.residente = 'N');

  insert into ge_riesgo_clientes
    (activo, pasivo, cantidad, tipo)
    (select sum(fug_obt_activo_cliente(a.cod_persona)) as activo,
            sum(fug_obt_pasivo_cliente(a.cod_persona)) as pasivo,
            count(1),
            '4' -- PERSONAS JURIDICAS
       from ge_clientes a, ba_personas b
      where a.cod_persona = b.cod_persona
        and b.tipo = 'J');

  insert into ge_riesgo_clientes
    (activo, pasivo, cantidad, tipo)
    (select sum(fug_obt_activo_cliente(a.cod_persona)) as activo,
            sum(fug_obt_pasivo_cliente(a.cod_persona)) as pasivo,
            count(1),
            '5' -- PERSONAS JURIDICAS RESIDENTES
       from ge_clientes a, ba_personas b
      where a.cod_persona = b.cod_persona
        and b.tipo = 'J'
        and a.residente = 'S');

  insert into ge_riesgo_clientes
    (activo, pasivo, cantidad, tipo)
    (select sum(fug_obt_activo_cliente(a.cod_persona)) as activo,
            sum(fug_obt_pasivo_cliente(a.cod_persona)) as pasivo,
            count(1),
            '6' -- PERSONAS JURIDICAS NO RESIDENTES
       from ge_clientes a, ba_personas b
      where a.cod_persona = b.cod_persona
        and b.tipo = 'J'
        and a.residente = 'N');

  insert into ge_riesgo_clientes
    (activo, pasivo, cantidad, tipo)
    (select sum(fug_obt_activo_cliente(a.cod_persona)) as activo,
            sum(fug_obt_pasivo_cliente(a.cod_persona)) as pasivo,
            count(1),
            '7' -- TODOS LOS CLIENTE
       from ge_clientes a, ba_personas b
      where a.cod_persona = b.cod_persona);
  commit;

  /*-----------------------------------------------------------------------------------*/
  /*    Actualiza el total, la suma del activo + pasivo, se hizo en un update a parte  /*
  /*                 para que no llame nuevamente a la funcion                         */
  /*-----------------------------------------------------------------------------------*/
  update ge_riesgo_clientes a
     set a.total = a.activo + a.pasivo
   where a.tipo = '1';
  update ge_riesgo_clientes a
     set a.total = a.activo + a.pasivo
   where a.tipo = '2';
  update ge_riesgo_clientes a
     set a.total = a.activo + a.pasivo
   where a.tipo = '3';
  update ge_riesgo_clientes a
     set a.total = a.activo + a.pasivo
   where a.tipo = '4';
  update ge_riesgo_clientes a
     set a.total = a.activo + a.pasivo
   where a.tipo = '5';
  update ge_riesgo_clientes a
     set a.total = a.activo + a.pasivo
   where a.tipo = '6';
  update ge_riesgo_clientes a
     set a.total       = a.activo + a.pasivo,
         a.porcent_act = 100, -- Tienen porcentaje 100% ya que es el total de los segmentos
         a.porcent_pas = 100,
         a.porcent_tot = 100,
         a.porcent_can = 100
   where a.tipo = '7';
  commit;

  /*-----------------------------------------------------------------------------------*/
  /*   Update que calcula el porcentaje del activo de todos los tipos de clientes      */
  /*-----------------------------------------------------------------------------------*/

  update ge_riesgo_clientes a
     set a.porcent_act = ((a.activo / (select aa.activo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '7')) * 100),
         a.porcent_pas = ((a.pasivo / (select aa.pasivo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '7')) * 100),
         a.porcent_tot = ((a.total / (select aa.total
                                        from ge_riesgo_clientes aa
                                       where aa.tipo = '7')) * 100),
         a.porcent_can = ((a.cantidad /
                         (select aa.cantidad
                              from ge_riesgo_clientes aa
                             where aa.tipo = '7')) * 100)
   where a.tipo = '1';

  update ge_riesgo_clientes a
     set a.porcent_act = ((a.activo / (select aa.activo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '7')) * 100),
         a.porcent_pas = ((a.pasivo / (select aa.pasivo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '7')) * 100),
         a.porcent_tot = ((a.total / (select aa.total
                                        from ge_riesgo_clientes aa
                                       where aa.tipo = '7')) * 100),
         a.porcent_can = ((a.cantidad /
                         (select aa.cantidad
                              from ge_riesgo_clientes aa
                             where aa.tipo = '7')) * 100)
   where a.tipo = '4';

  update ge_riesgo_clientes a
     set a.porcent_act = ((a.activo / (select aa.activo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '1')) * 100),
         a.porcent_pas = ((a.pasivo / (select aa.pasivo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '1')) * 100),
         a.porcent_tot = ((a.total / (select aa.total
                                        from ge_riesgo_clientes aa
                                       where aa.tipo = '1')) * 100),
         a.porcent_can = ((a.cantidad /
                         (select aa.cantidad
                              from ge_riesgo_clientes aa
                             where aa.tipo = '1')) * 100)
   where a.tipo = '2';

  update ge_riesgo_clientes a
     set a.porcent_act = ((a.activo / (select aa.activo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '1')) * 100),
         a.porcent_pas = ((a.pasivo / (select aa.pasivo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '1')) * 100),
         a.porcent_tot = ((a.total / (select aa.total
                                        from ge_riesgo_clientes aa
                                       where aa.tipo = '1')) * 100),
         a.porcent_can = ((a.cantidad /
                         (select aa.cantidad
                              from ge_riesgo_clientes aa
                             where aa.tipo = '1')) * 100)
   where a.tipo = '3';

  update ge_riesgo_clientes a
     set a.porcent_act = ((a.activo / (select aa.activo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '4')) * 100),
         a.porcent_pas = ((a.pasivo / (select aa.pasivo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '4')) * 100),
         a.porcent_tot = ((a.total / (select aa.total
                                        from ge_riesgo_clientes aa
                                       where aa.tipo = '4')) * 100),
         a.porcent_can = ((a.cantidad /
                         (select aa.cantidad
                              from ge_riesgo_clientes aa
                             where aa.tipo = '4')) * 100)
   where a.tipo = '5';

  update ge_riesgo_clientes a
     set a.porcent_act = ((a.activo / (select aa.activo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '4')) * 100),
         a.porcent_pas = ((a.pasivo / (select aa.pasivo
                                         from ge_riesgo_clientes aa
                                        where aa.tipo = '4')) * 100),
         a.porcent_tot = ((a.total / (select aa.total
                                        from ge_riesgo_clientes aa
                                       where aa.tipo = '4')) * 100),
         a.porcent_can = ((a.cantidad /
                         (select aa.cantidad
                              from ge_riesgo_clientes aa
                             where aa.tipo = '4')) * 100)
   where a.tipo = '6';

  commit;

end prc_gen_reporte_seg_client;
/

