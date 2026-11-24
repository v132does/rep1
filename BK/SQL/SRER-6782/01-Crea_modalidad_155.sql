------------------------------
-- 1-- genero modalidad 155 --
------------------------------

BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;

  IT.pro_gen_nue_modalidad(
    p_cod_ori_modalidad => 117,
    p_cod_nue_modalidad => 155,
    p_descripcion       => 'PRESTAMOS REC. AFD + OTROS IVA 10%',
    p_cod_modulo        => 10
  );
  COMMIT;
END;
/