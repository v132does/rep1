CREATE OR REPLACE PACKAGE BODY IT.PAG_INF IS

/* Generancion de transacciones de Ahorros */
PROCEDURE PR_PRO_TRA_AHORROS
 IS

V_FEC_ACTUAL DATE;
V_PRIDIAM DATE;
cursor ope_ah is
   select to_char(AH_MOVIMIENTOS_HIS.FECHA,'yyyymm') anomes,
          AH_MOVIMIENTOS_HIS.COD_USUARIO,
          AH_MOVIMIENTOS_HIS.COD_OFI_ORIGEN,
          BA_USUARIOS.COD_BANCA,
          AH_MOVIMIENTOS_HIS.COD_TRA_PADRE,
          AH_MOVIMIENTOS_HIS.COD_MONEDA,
          count(*) cantidad,
          sum(AH_MOVIMIENTOS_HIS.MONTO) total,
          AH_MOVIMIENTOS_HIS.COD_MAD_PADRE,
          AH_MOVIMIENTOS_HIS.COD_MOD_PADRE
     from GE_CLIENTES,
          GE_CTA_CLIENTES,
          AH_MOVIMIENTOS_HIS ,
          BA_USUARIOS
    where AH_MOVIMIENTOS_HIS.FECHA between v_pridiam and v_fec_actual
      and GE_CTA_CLIENTES.NRO_CUENTA = AH_MOVIMIENTOS_HIS.NRO_CUENTA
      and GE_CTA_CLIENTES.RELACION = 'P'
      and GE_CLIENTES.COD_PERSONA = GE_CTA_CLIENTES.COD_PERSONA
      and BA_USUARIOS.COD_USUARIO = GE_CLIENTES.COD_USU_OFICIAL
      and AH_MOVIMIENTOS_HIS.COD_MOD_PADRE = 3
      and AH_MOVIMIENTOS_HIS.COD_TRA_PADRE <> 310
      and AH_MOVIMIENTOS_HIS.NRO_CUENTA is not null
      and AH_MOVIMIENTOS_HIS.REVERSADO = 'N'
      and AH_MOVIMIENTOS_HIS.ESTADO = 'N'
      and AH_MOVIMIENTOS_HIS.MONTO is not null
      --and (substr(AH_MOVIMIENTOS_HIS.COD_USUARIO,1,3) not in ('caj','atm','mms','tes') or
      --     AH_MOVIMIENTOS_HIS.COD_TRA_PADRE in (346))
 group by to_char(AH_MOVIMIENTOS_HIS.FECHA,'yyyymm'),
                  AH_MOVIMIENTOS_HIS.COD_USUARIO,
                  AH_MOVIMIENTOS_HIS.COD_OFI_ORIGEN,
                  BA_USUARIOS.COD_BANCA,
                  AH_MOVIMIENTOS_HIS.COD_TRA_PADRE,
                  AH_MOVIMIENTOS_HIS.COD_MONEDA,
                  AH_MOVIMIENTOS_HIS.COD_MAD_PADRE,
                  AH_MOVIMIENTOS_HIS.COD_MOD_PADRE;

cursor ope_ah_men is
   select to_char(A.FECHA,'yyyymm') anomes,
          A.COD_USUARIO,
          A.COD_OFI_ORIGEN,
          A.COD_TRA_PADRE,
          A.COD_MONEDA,
          count(*) cantidad,
          A.COD_MODULO,
          A.COD_MODALIDAD,
          sum(A.MONTO) total,
          substr(A.HORA,1,2) hora,
          A.COD_MAD_PADRE,
          A.COD_MOD_PADRE
     from AH_MOVIMIENTOS_HIS a
    where A.FECHA between v_pridiam and v_fec_actual
      and A.COD_MOD_PADRE = 3 --or CC_MOVIMIENTOS_HIS.COD_USUARIO = 'homebk')
      and A.COD_MODULO = 3
      and A.COD_MODALIDAD in (31,32,33,34,35,36)
      and A.COD_TRA_PADRE <> 310
      --and A.COD_TRA_PADRE not in (321,322)
      and A.NRO_CUENTA is not null
      and A.REVERSADO = 'N'
      and A.ESTADO= 'N'
      and A.MONTO is not null
      --and (substr(AH_MOVIMIENTOS_HIS.COD_USUARIO,1,3) not in ('caj','atm','mms','tes')
      --            or AH_MOVIMIENTOS_HIS.COD_TRA_PADRE in (346))
      and a.rowid = (select min(b.rowid) from AH_MOVIMIENTOS_HIS b
                      where b.COD_USUARIO = a.COD_USUARIO
                        and b.HORA = a.HORA
                        and b.FECHA = a.FECHA
                        and b.NRO_CUENTA = a.NRO_CUENTA
                        and b.MONTO is not null)
      group by to_char(A.FECHA,'yyyymm'),A.COD_USUARIO,A.COD_OFI_ORIGEN,
               A.COD_TRA_PADRE,A.COD_MONEDA,A.COD_MODULO,
               A.COD_MODALIDAD,substr(A.HORA,1,2),
               A.COD_MAD_PADRE,A.COD_MOD_PADRE;
begin
   v_fec_actual := pag_cal.fu_obt_fec_actual(3);
   v_pridiam    := to_Date('01'||to_char(v_fec_actual,'MMYYYY'),'DDMMYYYY');
  for cl in ope_ah loop
    insert into GE_EST_TRANSACCIONES
              (ano,
               mes,
               cod_usuario,
               cod_oficina,
               cod_tra_padre,
               cod_moneda,
               cantidad,
               monto,
               cod_mod_padre,
               cod_mad_padre,
               cod_banca)
        values
              (to_number(substr(cl.anomes,1,4)),
               to_number(substr(cl.anomes,5,2)),
               cl.cod_usuario,
               cl.cod_ofi_origen,
               cl.cod_tra_padre,
               cl.cod_moneda,
               cl.cantidad,
               cl.total,
               cl.cod_mod_padre,
               cl.cod_mad_padre,
               cl.cod_banca);

  end loop;

for cl in ope_ah_men loop
       insert into GE_EST_TRA_HORA
                  (ano,
                   mes,
                   cod_usuario,
                   cod_oficina,
                   cod_tra_padre,
                   cod_moneda,
                   cantidad,
                   cod_modulo,
                   cod_modalidad,
                   monto,
                   hora,
                   cod_mad_padre,
                   cod_mod_padre)
            values(substr(cl.anomes,1,4),
                   substr(cl.anomes,5,2),
                   cl.cod_usuario,
                   cl.cod_ofi_origen,
                   cl.cod_tra_padre,
                   cl.cod_moneda,
                   cl.cantidad,
                   cl.cod_modulo,
                   cl.cod_modalidad,
                   cl.total,
                   cl.hora ,
                   cl.cod_mad_padre,
                   cl.cod_mod_padre);
   end loop;

/*PAG_INF
PR_PRO_TRA_CAJA
PR_PRO_TRA_CTA_CTES
PR_PRO_TRA_CAMBIOS
PR_PRO_TRA_AHORROS
PR_PRO_TRA_TARJETAS
PR_PRO_TRA_PRESTAMOS*/
end;
/* Generacion de transacciones de Cuentas Corrientes */
PROCEDURE PR_PRO_TRA_CTA_CTES
 IS

V_FEC_ACTUAL DATE;
V_PRIDIAM DATE;
V_CDTRANS NUMBER(3);
cursor ope_cc is
    select to_char(CC_MOVIMIENTOS_HIS.FECHA,'yyyymm') anomes,
           CC_MOVIMIENTOS_HIS.COD_USUARIO,
           CC_MOVIMIENTOS_HIS.COD_OFI_ORIGEN,
           BA_USUARIOS.COD_BANCA,
           CC_MOVIMIENTOS_HIS.COD_TRA_PADRE,
           CC_MOVIMIENTOS_HIS.COD_MONEDA,
           count(*) cantidad,
           sum(CC_MOVIMIENTOS_HIS.MONTO) total,
           CC_MOVIMIENTOS_HIS.COD_MAD_PADRE,
           CC_MOVIMIENTOS_HIS.COD_MOD_PADRE
      from GE_CLIENTES,
           GE_CTA_CLIENTES,
           CC_MOVIMIENTOS_HIS ,
           BA_USUARIOS
     where CC_MOVIMIENTOS_HIS.FECHA between v_pridiam and v_fec_actual
       and GE_CTA_CLIENTES.NRO_CUENTA = CC_MOVIMIENTOS_HIS.NRO_CUENTA
       and GE_CTA_CLIENTES.RELACION = 'P'
       and BA_USUARIOS.cod_usuario = GE_CLIENTES.cod_usu_oficial
       and GE_CLIENTES.cod_persona = GE_CTA_CLIENTES.COD_PERSONA
       and CC_MOVIMIENTOS_HIS.COD_MOD_PADRE = 4
       and CC_MOVIMIENTOS_HIS.COD_MODULO = 4 and CC_MOVIMIENTOS_HIS.COD_MODALIDAD in (41,42)
       and CC_MOVIMIENTOS_HIS.COD_TRA_PADRE <> 310
       and CC_MOVIMIENTOS_HIS.COD_TRA_PADRE not in (321,322)
       and CC_MOVIMIENTOS_HIS.NRO_CUENTA is not null
       and CC_MOVIMIENTOS_HIS.REVERSADO = 'N'
       and CC_MOVIMIENTOS_HIS.ESTADO = 'N'
       and CC_MOVIMIENTOS_HIS.MONTO is not null
       --and (substr(CC_MOVIMIENTOS_HIS.COD_USUARIO,1,3) not in ('caj','atm','mms','tes')
       -- or CC_MOVIMIENTOS_HIS.COD_TRA_PADRE in (346))
  group by to_char(CC_MOVIMIENTOS_HIS.FECHA,'yyyymm'),
           CC_MOVIMIENTOS_HIS.COD_USUARIO,
           CC_MOVIMIENTOS_HIS.COD_OFI_ORIGEN,
           BA_USUARIOS.COD_BANCA,
           CC_MOVIMIENTOS_HIS.COD_TRA_PADRE,
           CC_MOVIMIENTOS_HIS.COD_MONEDA,
           CC_MOVIMIENTOS_HIS.COD_MAD_PADRE,
           CC_MOVIMIENTOS_HIS.COD_MOD_PADRE;



cursor ope_cc_men is
   select to_char(A.FECHA,'yyyymm') anomes,
          A.COD_USUARIO,
          A.COD_OFI_ORIGEN,
          A.COD_TRA_PADRE,
          A.COD_MONEDA,
          count(*) cantidad,
          A.COD_MODULO,
          A.COD_MODALIDAD,
          sum(A.MONTO) total,
          substr(A.HORA,1,2) hora,
          A.COD_MAD_PADRE,
          A.COD_MOD_PADRE
     from CC_MOVIMIENTOS_HIS a
    where A.FECHA between v_pridiam and v_fec_actual
      and A.COD_MOD_PADRE = 4 --or CC_MOVIMIENTOS_HIS.COD_USUARIO = 'homebk')
      and A.COD_MODULO = 4 and A.COD_MODALIDAD in (41,42)
      and A.COD_TRA_PADRE <> 310
      and A.COD_TRA_PADRE not in (321,322)
      and A.NRO_CUENTA is not null
      and A.REVERSADO = 'N'
      and A.ESTADO= 'N'
      and A.MONTO is not null
      --and (substr(AH_MOVIMIENTOS_HIS.COD_USUARIO,1,3) not in ('caj','atm','mms','tes')
      --            or AH_MOVIMIENTOS_HIS.COD_TRA_PADRE in (346))
      and a.rowid = (select min(b.rowid) from CC_MOVIMIENTOS_HIS b
                      where b.COD_USUARIO = a.COD_USUARIO
                        and b.HORA = a.HORA
                        and b.FECHA = a.FECHA
                        and b.NRO_CUENTA = a.NRO_CUENTA
                        and b.MONTO is not null)
 group by to_char(A.FECHA,'yyyymm'),
          A.COD_USUARIO,
          A.COD_OFI_ORIGEN,
          A.COD_TRA_PADRE,
          A.COD_MONEDA,
          A.COD_MODULO,
          A.COD_MODALIDAD,
          substr(A.HORA,1,2),
          A.COD_MAD_PADRE,
          A.COD_MOD_PADRE;
BEGIN
   v_fec_actual := pag_cal.fu_obt_fec_actual(4);
   v_pridiam    := to_date('01'||to_char(v_fec_actual,'MMYYYY'),'DDMMYYYY');
   --v_cdtrans := 0;

   for cl in ope_cc loop
      insert into GE_EST_TRANSACCIONES
              (ano,
               mes,
               cod_usuario,
               cod_oficina,
               cod_tra_padre,
               cod_moneda,
               cantidad,
               monto,
               cod_mod_padre,
               cod_mad_padre,
               cod_banca)
        values
              (to_number(substr(cl.anomes,1,4)),
               to_number(substr(cl.anomes,5,2)),
               cl.cod_usuario,
               cl.cod_ofi_origen,
               cl.cod_tra_padre,
               cl.cod_moneda,
               cl.cantidad,
               cl.total,
               cl.cod_mod_padre,
               cl.cod_mad_padre,
               cl.cod_banca);
  end loop;

   for cl in ope_cc_men loop
      insert into GE_EST_TRA_HORA
                  (ano,
                   mes,
                   cod_usuario,
                   cod_oficina,
                   cod_tra_padre,
                   cod_moneda,
                   cantidad,
                   cod_modulo,
                   cod_modalidad,
                   monto,
                   hora,
                   cod_mad_padre,
                   cod_mod_padre)
            values(substr(cl.anomes,1,4),
                   substr(cl.anomes,5,2),
                   cl.cod_usuario,
                   cl.cod_ofi_origen,
                   cl.cod_tra_padre,
                   cl.cod_moneda,
                   cl.cantidad,
                   cl.cod_modulo,
                   cl.cod_modalidad,
                   cl.total,
                   cl.hora ,
                   cl.cod_mad_padre,
                   cl.cod_mod_padre);
   end loop;



END;
/* Generación de transacciones de Caja */
PROCEDURE PR_PRO_TRA_CAJA
 IS

V_FEC_ACTUAL DATE;
V_PRIDIAM DATE;
BEGIN
v_fec_actual := pag_cal.fu_obt_fec_actual(1);
v_pridiam    := to_Date('01'||to_char(v_fec_actual,'MMYYYY'),'DDMMYYYY');

  insert into GE_EST_TRANSACCIONES
              (ano,
               mes,
               cod_usuario,
               cod_oficina,
               cod_banca,
               cod_tra_padre,
               cod_moneda,
               cantidad,
               monto,
               cod_mad_padre,
               cod_mod_padre)
        select to_char(cjm.fecha,'YYYY'),
               to_char(cjm.fecha,'MM'),
               cjm.cod_usuario,
               cjm.cod_oficina,
               bau.cod_banca,
               cjm.cod_tra_padre,
               cjm.cod_moneda,
               count(*),
               sum(monto),
               cjm.cod_mad_padre, --91
               cjm.cod_mod_padre
         from GE_CLIENTES gec ,
              GE_CTA_CLIENTES gecl ,
              CJ_MOVIMIENTOS_HIS cjm,
              BA_USUARIOS bau
        where cjm.fecha between v_pridiam and v_fec_actual
          and gecl.nro_cuenta = cjm.nro_cuenta
          and bau.cod_usuario = gec.cod_usu_oficial
          and gecl.relacion = 'P'
          and gec.cod_persona = gecl.cod_persona
          and cod_tra_padre not in (201,202,203,204,205,211,212,213)
          and nvl(cjm.estado,' ') <> 'R'
     group by to_char(cjm.fecha,'YYYY'),
              to_char(cjm.fecha,'MM'),
              cjm.cod_usuario,
              cjm.cod_oficina,
              bau.cod_banca,
              cjm.cod_tra_padre,
              cjm.cod_moneda,
              cjm.cod_mad_padre,
              cjm.cod_mod_padre;

   insert into GE_EST_TRA_HORA
          (ANO,
           MES,
           COD_USUARIO,
           COD_OFICINA,
           COD_TRA_PADRE,
           COD_MONEDA,
           CANTIDAD,
           COD_MODULO,
           COD_MODALIDAD,
           MONTO,
           HORA,
           COD_MAD_PADRE,
           COD_MOD_PADRE)
    select to_char(CJ_MOVIMIENTOS_HIS.FECHA,'YYYY'),
           to_char(CJ_MOVIMIENTOS_HIS.FECHA,'MM'),
           CJ_MOVIMIENTOS_HIS.COD_USUARIO,
           CJ_MOVIMIENTOS_HIS.COD_OFICINA,
           CJ_MOVIMIENTOS_HIS.COD_TRA_PADRE,
           CJ_MOVIMIENTOS_HIS.COD_MONEDA,
           count(*),
           CJ_MOVIMIENTOS_HIS.COD_MAD_PADRE,--91
           CJ_MOVIMIENTOS_HIS.COD_MOD_PADRE,
           sum(CJ_MOVIMIENTOS_HIS.MONTO),
           substr(CJ_MOVIMIENTOS_HIS.HORA,1,2),
           CJ_MOVIMIENTOS_HIS.COD_MAD_PADRE,--91
           CJ_MOVIMIENTOS_HIS.COD_MOD_PADRE
      from CJ_MOVIMIENTOS_HIS
     where CJ_MOVIMIENTOS_HIS.FECHA between v_pridiam and v_fec_actual
       and CJ_MOVIMIENTOS_HIS.COD_TRA_PADRE not in (201,202,203,204,205,211,212,213)
       and nvl(CJ_MOVIMIENTOS_HIS.ESTADO,' ') <> 'R'
  group by to_char(CJ_MOVIMIENTOS_HIS.FECHA,'YYYY'),
           to_char(CJ_MOVIMIENTOS_HIS.FECHA,'MM'),
           CJ_MOVIMIENTOS_HIS.COD_USUARIO,
           CJ_MOVIMIENTOS_HIS.COD_OFICINA,
           CJ_MOVIMIENTOS_HIS.COD_TRA_PADRE,
           CJ_MOVIMIENTOS_HIS.COD_MONEDA,
           CJ_MOVIMIENTOS_HIS.COD_MAD_PADRE,--91
           CJ_MOVIMIENTOS_HIS.COD_MOD_PADRE,
           substr(CJ_MOVIMIENTOS_HIS.HORA,1,2),
           CJ_MOVIMIENTOS_HIS.COD_MAD_PADRE,
           CJ_MOVIMIENTOS_HIS.COD_MOD_PADRE;
END;
/* Generación de transacciones de Prestamos */
PROCEDURE PR_PRO_TRA_PRESTAMOS
 IS

V_FEC_ACTUAL DATE;
V_PRIDIAM DATE;
cursor ope_pr is
    Select to_char(a.FECHA,'yyyymm') anomes,
           a.COD_USUARIO,
           a.COD_OFI_ORIGEN,
           BA_USUARIOS.COD_BANCA,
           a.COD_TRA_PADRE,
           a.COD_MONEDA,
           count(*) cantidad,
           sum(a.MONTO) total,
           a.COD_MAD_PADRE,
           a.COD_MOD_PADRE
      from GE_CLIENTES,
           GE_CTA_CLIENTES,
           PR_MOVIMIENTOS_HIS a,
           BA_USUARIOS
     where a.FECHA between v_pridiam and v_fec_actual
       and GE_CTA_CLIENTES.NRO_CUENTA = a.NRO_CUENTA
       and GE_CTA_CLIENTES.RELACION = 'P'
       and GE_CLIENTES.COD_PERSONA = GE_CTA_CLIENTES.COD_PERSONA
       and BA_USUARIOS.COD_USUARIO = GE_CLIENTES.COD_USU_OFICIAL
       and a.COD_TRA_PADRE not in (945,900)
       and a.COD_MODULO = 6
       and a.NRO_CUENTA is not null
       and a.REVERSADO = 'N'
       and a.ESTADO = 'N'
       and a.MONTO is not null
       --and substr(PR_MOVIMIENTOS_HIS.COD_USUARIO,1,3) not in ('caj','atm','mms','tes')
       and a.rowid = (select min(b.rowid) from PR_MOVIMIENTOS_HIS b
                       where b.COD_USUARIO = a.COD_USUARIO
                         and b.HORA = a.HORA
                         and b.FECHA = a.FECHA
                         and b.NRO_CUENTA = a.NRO_CUENTA
                         and b.MONTO is not null)
  group by to_char(a.FECHA,'yyyymm'),
           a.COD_USUARIO,
           a.COD_OFI_ORIGEN,
           BA_USUARIOS.COD_BANCA,
           a.COD_TRA_PADRE,
           a.COD_MONEDA,
           a.COD_MAD_PADRE,
           a.COD_MOD_PADRE;

cursor ope_pr_men is
   select to_char(A.FECHA,'yyyymm') anomes,
          A.COD_USUARIO,
          A.COD_OFI_ORIGEN,
          A.COD_TRA_PADRE,
          A.COD_MONEDA,
          count(*) cantidad,
          A.COD_MODULO,
          A.COD_MODALIDAD,
          sum(A.MONTO) total,
          substr(A.HORA,1,2) hora,
          A.COD_MAD_PADRE,
          A.COD_MOD_PADRE
     from PR_MOVIMIENTOS_HIS a
    where A.FECHA between v_pridiam and v_fec_actual
      and A.COD_MOD_PADRE = 6
      and A.COD_MODULO = 6
      and A.COD_TRA_PADRE not in (945,900)
      and A.NRO_CUENTA is not null
      and A.REVERSADO = 'N'
      and A.ESTADO= 'N'
      and A.MONTO is not null
       --and (substr(AH_MOVIMIENTOS_HIS.COD_USUARIO,1,3) not in ('caj','atm','mms','tes')
       --           or AH_MOVIMIENTOS_HIS.COD_TRA_PADRE in (346))
      and a.rowid = (select min(b.rowid) from PR_MOVIMIENTOS_HIS b
                      where b.COD_USUARIO = a.COD_USUARIO
                        and b.HORA = a.HORA
                        and b.FECHA = a.FECHA
                        and b.NRO_CUENTA = a.NRO_CUENTA
                        and b.MONTO is not null)
      group by to_char(A.FECHA,'yyyymm'),
               A.COD_USUARIO,A.COD_OFI_ORIGEN,
               A.COD_TRA_PADRE,
               A.COD_MONEDA,
               A.COD_MODULO,
               A.COD_MODALIDAD,
               substr(A.HORA,1,2),
               A.COD_MAD_PADRE,
               A.COD_MOD_PADRE;
begin
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   v_pridiam    := to_date('01'||to_char(v_fec_actual,'MMYYYY'),'DDMMYYYY');
  for cl in ope_pr loop
    insert into GE_EST_TRANSACCIONES
              (ano,
               mes,
               cod_usuario,
               cod_oficina,
               cod_banca,
               cod_tra_padre,
               cod_moneda,
               cantidad,
               monto,
               cod_mad_padre,
               cod_mod_padre)
         values
              (substr(cl.anomes,1,4),
               substr(cl.anomes,5,2),
               cl.cod_usuario,
               cl.cod_ofi_origen,
               cl.cod_banca,
               cl.cod_tra_padre,
               cl.cod_moneda,
               cl.cantidad,
               cl.total,
               cl.cod_mad_padre,
               cl.cod_mod_padre);
  end loop;

  for cl in ope_pr_men loop
       insert into GE_EST_TRA_HORA
                  (ano,
                   mes,
                   cod_usuario,
                   cod_oficina,
                   cod_tra_padre,
                   cod_moneda,
                   cantidad,
                   cod_modulo,
                   cod_modalidad,
                   monto,
                   hora,
                   cod_mad_padre,
                   cod_mod_padre)
            values(substr(cl.anomes,1,4),
                   substr(cl.anomes,5,2),
                   cl.cod_usuario,
                   cl.cod_ofi_origen,
                   cl.cod_tra_padre,
                   cl.cod_moneda,
                   cl.cantidad,
                   cl.cod_modulo,
                   cl.cod_modalidad,
                   cl.total,
                   cl.hora ,
                   cl.cod_mad_padre,
                   cl.cod_mod_padre);
   end loop;
END;

END PAG_INF;
/

