create or replace force view it.sv_crc_vinculos_mod as
select o.linea, o.registro, o.fecha
  from (select rpad('VINCULOS', 10) ||
               rpad(to_char(c.fec, 'yyyymmdd'),8,' ') ||
               lpad(fug_obt_cod_entidad, 4, 0) ||
               lpad(c.can_reg, 9, 0) linea, 0 registro, c.fec fecha
          from (select max(a.fecha) fec , count(*) can_reg
                  from sb_crc_act_per_vin_det a
                 where a.nom_referencia = 'VINCULOS') c) o

UNION ALL
select o2.linea, o2.registro, o2.fecha
  from (select lpad(nro_formulario, 3, 0) ||
               decode (pas_cri.fu_obt_cod_entidad, 2079, rpad(lpad(cod_oficina, 2, 0),4,' '), 1007, lpad(cod_oficina, 4, 0),
               2036,rpad(lpad(cod_oficina,2,0), 4, ' '),rpad(cod_oficina, 4, ' ')) ||
               lpad(nvl(tip_operacion,0), 3, 0) ||
               rpad(nro_operacion, 60, ' ') ||
               rpad(cod_mon_iso, 3, ' ') ||
               rpad(nvl(tip_documento,' '), 3, ' ') ||
               decode(tip_documento, 'RUC',
                      decode(pas_cri.fu_obt_cod_entidad, 2079,
                              rpad(nvl(nro_documento, ' ') || '-' ||
                                    fue_obt_ruc_dig_verificador(nro_documento), 30, ' '), 6004,
                              rpad(nvl(nro_documento, ' ') || '-' ||
                                    fue_obt_ruc_dig_verificador(nro_documento), 30, ' '),
                              rpad(nvl(nro_documento, ' '), 30, ' ')) ,
               rpad(nvl(nro_documento, ' '), 30, ' ')) ||
               rpad(nvl(to_char(fec_nacimiento, 'yyyymmdd'),' '), 8,' ') ||
               rpad(nvl(nombres,' '), 255,' ') ||
               rpad(nvl(apellidos,' '), 100,' ') ||
               lpad(tip_vinculo, 3, 0) ||
               nvl(per_vinculada, 'N') ||
               lpad(nro_registro, 9, 0) linea, nro_registro registro, fecha
         from  sb_crc_act_per_vin_det where nom_referencia = 'VINCULOS' order by nro_registro) o2
order by fecha, registro;

