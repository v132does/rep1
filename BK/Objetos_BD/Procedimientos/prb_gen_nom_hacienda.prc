CREATE OR REPLACE PROCEDURE IT.PRB_GEN_NOM_HACIENDA is
---Para generación de datos Cuentas Nomina asociadas a Entes de Pago Salario - Datos Adicionales
  cursor datos is

   select max(fecha) fecha, h.nro_cuenta,h.cod_modulo,h.cod_modalidad,h.cod_moneda
         from ah_movimientos_his h
         where ((h.COD_TRANSACCION = 503 and
               h.COD_TRA_PADRE in (309, 320, 382) and h.COD_TASA is null and
               h.VAL_TASA is null) or
               (h.cod_transaccion = 591 and h.cod_tra_padre = 355) or
               (h.cod_transaccion = 590 and h.cod_tra_padre = 354))
            group by h.nro_cuenta,h.cod_modulo,h.cod_modalidad,h.cod_moneda;
   
   cursor datos_dep is 
   select max(h.fecha) fecha,h.nro_cuenta,h.cod_modulo,h.cod_modalidad
          from ah_movimientos_his h
         where h.COD_TRANSACCION in
               ('602', '690', '606', '607', '613', '614', '615', '632')
           group by h.nro_cuenta,h.cod_modulo,h.cod_modalidad;
           
   cursor datos_cc is
    select max(fecha) fecha, h.nro_cuenta,h.cod_modulo,h.cod_modalidad,h.cod_moneda
          from cc_movimientos_his h
         where ((h.COD_TRANSACCION = 503 and
               h.COD_TRA_PADRE in (309, 320, 382) and h.COD_TASA is null and
               h.VAL_TASA is null) or
               (h.cod_transaccion = 591 and h.cod_tra_padre = 355) or
               (h.cod_transaccion = 590 and h.cod_tra_padre = 354))
         group by h.nro_cuenta,h.cod_modulo,h.cod_modalidad,h.cod_moneda;
   cursor datos_cc_dep is
   select max(h.fecha) fecha,h.nro_cuenta,h.cod_modulo,h.cod_modalidad
          from cc_movimientos_his h
         where h.COD_TRANSACCION in
               ('602', '690', '606', '607', '613', '614', '615', '632')
           group by h.nro_cuenta,h.cod_modulo,h.cod_modalidad;

begin
  
  
  execute immediate 'truncate table ge_cta_ope_tmp';
  ---para la insersión de datos se usa directamente los querys de la vista vg_cta_nom_hacienda
  ---se insertan los datos 
  execute immediate 'insert into ge_cta_ope_tmp (cod_ente,empresa,cod_modulo,
                       cod_modalidad,nro_cuenta,tipo_cta,sub_mod,sub_mod_cta,cod_moneda,cod_persona,
                       cliente,fec_apertura,cheq_activas)
                       select e.cod_ente,
                       fue_obt_nom_persona(e.cod_persona) empresa,
                       ah.cod_modulo,
                       ah.cod_modalidad,
                       ah.nro_cuenta,
                       ''AHO'' tipo_cta,
                       ah.cod_sub_modalidad sub_mod,
                       case
                         when (ah.cod_sub_modalidad = ''6'') then
                          ''AGUINALDO''
                         else
                          ''NOMINA''
                       end sub_mod_cta,
                       ah.cod_moneda,
                       ge.cod_persona,
                       fue_obt_nom_persona(ge.cod_persona) cliente,
                       ah.fec_apertura,
                       (select count(1)
                          from cc_chequeras ce
                         where ce.nro_cuenta = ah.nro_cuenta
                           and ce.estado = ''E'') cheq_activas
                  from ah_cta_vistas ah, ge_entes e, ge_cta_clientes ge
                 where ah.cod_ente is not null
                   and ah.cod_ente = e.cod_ente
                   and e.tipo = ''SU''
                   and e.cod_persona != 11198
                   and ah.nro_cuenta = ge.nro_cuenta
                   and ge.relacion = ''P''
                union all
                select e.cod_ente,
                       fue_obt_nom_persona(e.cod_persona) empresa,
                       ah.cod_modulo,
                       ah.cod_modalidad,
                       ah.nro_cuenta,
                       ''CC'' tipo_cta,
                       ah.cod_sub_modalidad sub_mod,
                       case
                         when (ah.cod_sub_modalidad = ''6'') then
                          ''AGUINALDO''
                         else
                          ''NOMINA''
                       end sub_mod_cta,
                       ah.cod_moneda,
                       ge.cod_persona,
                       fue_obt_nom_persona(ge.cod_persona) cliente,
                       ah.fec_apertura,
                      (select count(1)
                          from cc_chequeras ce
                         where ce.nro_cuenta = ah.nro_cuenta
                           and ce.estado = ''E'') cheq_activas
                  from cc_cta_corrientes ah, ge_entes e, ge_cta_clientes ge
                 where ah.cod_ente is not null
                   and ah.cod_ente = e.cod_ente
                   and e.tipo = ''SU''
                   and e.cod_persona != 11198
                   and ah.nro_cuenta = ge.nro_cuenta
                   and ge.relacion = ''P''';
                  
  commit;
  


BEGIN 

   for i in datos  loop
    update ge_cta_ope_tmp p set p.fec_ult_extraccion=i.fecha
    where p.nro_cuenta=i.nro_cuenta
    and p.cod_modulo=i.cod_modulo
    and p.cod_modalidad=i.cod_modalidad
    and p.cod_moneda=i.cod_moneda;
      
   end loop; 
   
   for reg in datos_dep loop
    update ge_cta_ope_tmp p set p.fec_ult_deposito=reg.fecha
    where p.nro_cuenta=reg.nro_cuenta
    and p.cod_modulo=reg.cod_modulo
    and p.cod_modalidad=reg.cod_modalidad;
   end loop;
   
   for j in datos_cc  loop
    update ge_cta_ope_tmp p set p.fec_ult_extraccion=j.fecha
    where p.nro_cuenta=j.nro_cuenta
    and p.cod_modulo=j.cod_modulo
    and p.cod_modalidad=j.cod_modalidad
    and p.cod_moneda=j.cod_moneda;
    
   end loop; 
   
    for x in datos_cc_dep loop
    update ge_cta_ope_tmp p set p.fec_ult_deposito=x.fecha
    where p.nro_cuenta=x.nro_cuenta
    and p.cod_modulo=x.cod_modulo
    and p.cod_modalidad=x.cod_modalidad;

   end loop;
end;
   
  
end PRB_GEN_NOM_HACIENDA;
/

