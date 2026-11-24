CREATE OR REPLACE PROCEDURE IT.PRC_INV_SOBREGIROS is
CURSOR DATOS IS
select a.cod_persona Riesgo,
       b.nom_completo Nombre_Cliente,
       (case
         when t.DIA_ATRASO >= 61 and t.DIA_ATRASO <= 90then e.rub_as_vencido when
          t.DIA_ATRASO >= 91 and t.DIA_ATRASO <= 180 then
          e.rub_as_gestion
         when t.DIA_ATRASO > 180 THEN
          e.rub_as_moroso
         when exists (select 1
                 from cc_lin_sobregiros f
                where f.nro_cuenta = t.nro_cuenta) then
          e.rub_as_autorizado
         else
          e.rub_as_transitorio
       end) Cta_Contable,
       t.nro_cuenta,
       t.sucursal Sucursal,
       t.cuenta Producto,
       t.subcuenta Subcuenta,
       t.cod_moneda Cod_moneda,
       nvl(t.SAL_TOTAL,0) Sal_Total,
       nvl(t.SAL_RETENIDO,0) Sal_Retenido,
       nvl(t.SAL_BLOQUEADO,0) Sal_bloqueado,
       nvl(t.MTO_EMBARGO,0) Mto_Embargo,
       nvl(t.SAL_TOTAL,0) - nvl(t.SAL_RETENIDO,0) - nvl(t.SAL_BLOQUEADO,0) Sal_disponible,
       nvl(f.monto,0) Monto_Linea,
       /*(nvl(t.SAL_TOTAL,0) - nvl(t.SAL_RETENIDO,0) - nvl(t.SAL_BLOQUEADO,0)) - nvl(f.monto,0) Excesos,*/
       case 
         when nvl(t.SAL_TOTAL,0) - nvl(t.SAL_RETENIDO,0) - nvl(t.SAL_BLOQUEADO,0) < 0 then
              (nvl(t.SAL_TOTAL,0) - nvl(t.SAL_RETENIDO,0) - nvl(t.SAL_BLOQUEADO,0)) + nvl(f.monto,0) /*formula de Riesgos segun mail 27.09.2010*/
         else 0
       end Excesos,
       pai_dtm_v.FU_OBT_fec_actual(3) - t.DIA_ATRASO +1 Fec_Entrada,
       f.fec_vencimiento Fec_Vencimiento,
       d.nombre Gestor,
       pag_cal.fu_obt_fec_actual(1) fecha
  from simgia_cc_cta_corrientes t,
       ge_cta_clientes          a,
       ba_personas              b,
       ge_clientes              c,
       ba_usuarios              d,
       simgia_cc_cta_cc_conta   e,
       cc_lin_sobregiros        f
 where a.nro_cuenta = t.nro_cuenta
   and a.relacion = 'P'
   and a.cod_persona = b.cod_persona
   and c.cod_persona = b.cod_persona
   and d.cod_usuario = c.cod_usu_oficial
   and e.nro_cuenta = t.nro_cuenta
   and f.nro_cuenta(+) = a.nro_cuenta
   and nvl(f.estado,'x')!= 'V'
   and nvl(t.sal_total, 0) - nvl(t.sal_retenido, 0) -
       nvl(t.sal_bloqueado, 0) < 0;

Begin
  FOR X IN DATOS LOOP
    begin
      insert into cc_sob_inventario (cod_persona,
                                     nom_completo,
                                     cta_contable,
                                     nro_cuenta,
                                     cod_oficina,
                                     producto,
                                     subcta,
                                     cod_moneda,
                                     sal_total,
                                     sal_retenido,
                                     sal_bloqueado,
                                     mto_embargo,
                                     sal_disponible,
                                     monto_linea,
                                     excesos,
                                     fec_entrada,
                                     fec_vencimiento,
                                     gestor,
                                     fecha)
                              values (x.riesgo,
                                      x.nombre_cliente,
                                      x.cta_contable,
                                      x.nro_cuenta,
                                      x.sucursal,
                                      x.producto,
                                      x.Subcuenta,
                                      x.cod_moneda,
                                      x.sal_total,
                                      x.sal_retenido,
                                      x.sal_bloqueado,
                                      x.mto_embargo,
                                      x.sal_disponible,
                                      x.monto_linea,
                                      x.excesos,
                                      x.fec_entrada,
                                      x.fec_vencimiento,
                                      x.gestor,
                                      x.fecha);
    exception
      when others then
        RAISE_APPLICATION_ERROR(-20000, 'ERROR AL INSERTAR DATOS EN cc_sob_inventario: PRC_INV_SOBREGIROS:' || SQLERRM);
    end;
  END LOOP;
  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
  RAISE_APPLICATION_ERROR(-20001, 'ERROR: PRC_INV_SOBREGIROS:' || SQLERRM);
end PRC_INV_SOBREGIROS;
/

