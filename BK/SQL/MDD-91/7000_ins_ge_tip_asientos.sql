-- Catalogo tip asientos FLI/REPO (solo GS)
-- Destino: homolog uenodesa5 primero; no ejecutar en FINDIA.
-- Tips: 9901/9903 (acuerdo de recompra)  9902/9904 (costo de recompra, solo 139/140)
--       9908/9909 (cesion / liberacion de garantia)
-- Una fila GS por pata. sector NULL, residente X. ind_plazo=S solo en titulo 12P.
-- Idempotente (MERGE). Identificacion por codigo + rubro; descripcion = hecho de negocio (sin prefijo ticket).
-- Release path: SQL/MDD-91/7000_ins_ge_tip_asientos.sql

begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

declare
  v_ajeno number;
begin
  select count(*)
    into v_ajeno
    from it.ge_tip_asientos t
   where t.cod_tip_asiento in (9901, 9902, 9903, 9904, 9908, 9909)
     and t.cod_moneda = 'GS'
     and (t.cod_tip_asiento, t.nro_linea, t.cod_rubro, t.tip_movimiento) not in (
           (9901, 1, '212301260200099', 'C'),
           (9902, 1, '132201590201099', 'D'),
           (9903, 1, '212301260200099', 'D'),
           (9904, 1, '132201590201099', 'C'),
           (9904, 2, '710107070400099', 'D'),
           (9908, 1, '132201530200199', 'D'),
           (9908, 2, '12P101230200399', 'C'),
           (9909, 1, '132201530200199', 'C'),
           (9909, 2, '12P101230200399', 'D')
         );

  if v_ajeno > 0 then
    raise_application_error(-20091,
      'Catalogo FLI/REPO: tips 9901/9902/9903/9904/9908/9909 GS ya existen con otro rubro o D/C.');
  end if;
end;
/

merge into it.ge_tip_asientos dst
using (
  -- Prototipo Excel (sin prefijo ticket); nombres completos — descripcion VARCHAR2(100)
  -- 9901 alta acuerdo DEAL (capital; +interes en REPO) — 138/139/140
  select 9901 cod_tip_asiento, 1 nro_linea, '212301260200099' cod_rubro,
         'ALTA ACUERDO DEAL' descripcion, 'C' tip_movimiento, 'N' ind_plazo from dual
  union all
  -- 9902 alta interes PERDIDA — 139/140 (DEAL ya va en 9901)
  select 9902, 1, '132201590201099', 'ALTA INTERES PERDIDA', 'D', 'N' from dual
  union all
  -- 9903 baja acuerdo DEAL — 138/139/140
  select 9903, 1, '212301260200099', 'BAJA ACUERDO DEAL', 'D', 'N' from dual
  union all
  -- 9904 baja interes a resultado — 139/140
  select 9904, 1, '132201590201099', 'BAJA INTERES PERDIDA', 'C', 'N' from dual
  union all
  select 9904, 2, '710107070400099', 'BAJA INTERES', 'D', 'N' from dual
  union all
  -- 9908 cesion garantia
  select 9908, 1, '132201530200199', 'ALTA GARANTIA DEUDORES', 'D', 'N' from dual
  union all
  select 9908, 2, '12P101230200399', 'ALTA GARANTIA TITULO', 'C', 'S' from dual
  union all
  -- 9909 liberacion garantia
  select 9909, 1, '132201530200199', 'BAJA GARANTIA DEUDORES', 'C', 'N' from dual
  union all
  select 9909, 2, '12P101230200399', 'BAJA GARANTIA TITULO', 'D', 'S' from dual
) src
on (dst.cod_tip_asiento = src.cod_tip_asiento
    and dst.nro_linea = src.nro_linea
    and dst.cod_moneda = 'GS'
    and nvl(dst.cod_sec_contable, '#') = '#'
    and dst.ind_residente = 'X'
    and dst.ind_deudor = 'N'
    and dst.ind_plazo = src.ind_plazo
    and dst.ind_producto = 'N')
when matched then update set
  dst.descripcion = src.descripcion
when not matched then insert (
  cod_tip_asiento, nro_linea, cod_rubro, descripcion, tip_movimiento,
  cod_moneda, cod_sec_contable, ind_residente, ind_deudor, ind_plazo,
  ind_producto, tip_renovacion, est_cuenta, tip_cuenta, tip_interes,
  cat_automatica, cod_sit_contable, cod_oficina)
values (
  src.cod_tip_asiento, src.nro_linea, src.cod_rubro, src.descripcion,
  src.tip_movimiento, 'GS', null, 'X', 'N', src.ind_plazo, 'N',
  null, null, null, null, null, null, null);

commit;
/
