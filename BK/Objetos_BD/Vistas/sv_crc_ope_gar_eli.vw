create or replace force view it.sv_crc_ope_gar_eli as
select o.linea, o.registro, o.fecha
  from (select rpad('OPEGARAN', 10) ||
               rpad(to_char(s.fec_periodo, 'yyyymmdd'),8,' ') ||
               lpad(s.cod_entidad, 4, 0) ||
               lpad(c.can_reg, 9, 0) linea, 0 registro, s.fec_periodo fecha
          from sb_crc_ope_garantias s,
              (select a.fecha fec , count(*) can_reg
                 from sb_crc_ope_garantias_det a
                where a.nom_referencia ='OPEGARELI'
               group by a.fecha) c
         where s.fec_periodo = fec
           and s.nom_referencia ='OPEGARELI') o
UNION ALL
select o2.linea, o2.registro, o2.fecha
  from (select lpad(nro_formulario, 3, 0) ||
               decode (pas_cri.fu_obt_cod_entidad, 2079, rpad(lpad(cod_ofi_operacion, 2, 0),4,' '), 1007, lpad(cod_ofi_operacion, 4, 0),
                       2036,rpad(lpad(cod_ofi_operacion,2,0), 4, ' '),rpad(cod_ofi_operacion, 4, ' ')) ||
               lpad(nvl(tip_operacion,0), 3, 0) ||
               rpad(nvl(nro_operacion, ' '), 60, ' ') ||
               rpad(nvl(cod_mon_iso_operacion, ' '), 3, ' ') ||
               decode (pas_cri.fu_obt_cod_entidad, 2079, rpad(lpad(cod_ofi_garantia, 2, 0),4,' '), 1007, lpad(cod_ofi_garantia, 4, 0),
                       2036,rpad(lpad(cod_ofi_garantia,2,0), 4, ' '),rpad(cod_ofi_garantia, 4, ' ')) ||
               rpad(nvl(cod_mon_iso_garantia, ' '), 3, ' ') ||
               rpad(nvl(to_char(nro_garantia), ' '), 60, ' ') ||
               rpad(nvl(replace(fub_obt_rub_formateado(rub_con_garantia),'.',null),' '), 18) ||
               lpad(to_char(nvl((mto_equ_utilizado*100),0)),20,'0') ||
               lpad(nro_registro, 9, 0) linea, nro_registro registro, fecha
         from  sb_crc_ope_garantias_det
        where  nom_referencia ='OPEGARELI' order by nro_registro) o2
order by fecha, registro;

