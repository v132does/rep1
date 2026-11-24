create or replace function it.fup_obt_tip_pre_com_cartera (p_nro_operacion in pr_cuo_com_cartera.nro_operacion%type,
                                                  p_cod_entidad in pr_cuo_com_cartera.cod_ente%type, p_tipo varchar2 )
return varchar2 is
v_can_cuo_capital pr_cta_prestamos.can_cuotas%type;
v_tip_prestamo    pr_solicitudes.tipo%type;


       CURSOR cuo_ctas
         (
            p_cod_entidad   IN pr_com_cartera.cod_ente%TYPE,
            p_nro_operacion IN pr_com_cartera.nro_operacion%TYPE
         ) IS
       SELECT c.nro_operacion, c.nro_cuota, c.fec_vencimiento, c.mto_cuota, c.nro_cheque,
                   c.cod_banco, c.cta_libradora, c.fec_emision, c.mto_cheque, c.nom_librador,
                   c.ape_librador, c.nro_doc_librador, c.cod_tip_doc_librador, c.cod_sex_librador,
                   nvl(c.sal_capital, 0) sal_capital, nvl(c.sal_interes, 0) sal_interes
              FROM pr_cuo_com_cartera c
             WHERE c.cod_ente = p_cod_entidad
               AND c.nro_operacion = p_nro_operacion
             ORDER BY c.nro_operacion, c.nro_cuota;
BEGIN
    if p_tipo='CONSUMO' THEN
        v_can_cuo_capital              := 0;
        v_tip_prestamo                 := 'A';
        for x in cuo_ctas(p_cod_entidad,p_nro_operacion )  loop
          if nvl(x.sal_capital,0)>0 then
            v_can_cuo_capital := v_can_cuo_capital + 1;
          end if;
        end loop;
        if v_can_cuo_capital =1 then
           v_tip_prestamo                 := 'P';
        end if;
     else
           v_tip_prestamo                 := 'D';
     end if;
        return v_tip_prestamo;
END;
/

