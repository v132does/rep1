CREATE OR REPLACE TRIGGER IT.TB_PR_CTA_GASTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_CTA_GASTOS
 FOR EACH ROW
declare
--Variables--
   v_exi_transaccion varchar2(1);
BEGIN
  if deleting then
     --18/11/2013 PN DI: Verifica si existe la transaccion en el grupo de las transacciones que no se pueden eliminar que se encuentran en el grupo 557 ( CARGOS ADICIONALES NO ELIMINAR)--    
     v_exi_transaccion := FUP_EXI_GRU_TRANSAC(P_COD_GRU_TRANSACCION => 557, P_COD_TRANSACCION => :old.cod_transaccion, P_COD_MODULO => 6, P_COD_MODALIDAD => 61);

      /* 18/11/2013 PN DI: Se inhabilitó porque la misma fue configurada en la tabla ge_gru_transaccioones entre las transacciones
                           que no se deben eliminar de la tabla PR_CTA_GASTOS*/
      /*if :old.cod_transaccion = 7012 then
         raise_application_error(-20000,'No puede eliminar Cargos de Gastos Judiciales, Realice cobro contra cuenta contable');
      end if; */

      /* 18/11/2013 PN DI: Se agrega para que el control se realice en base a las transacciones que se encuentran agrupadas en el grupo 557 ( CARGOS ADICIONALES NO ELIMINAR)*/
      if nvl(v_exi_transaccion, 'S') = 'S' then
         raise_application_error(-20000,'No puede eliminar la transacción '||:old.cod_transaccion||', Realice cobro contra cuenta contable');
      end if;
   end if;
END;
/

