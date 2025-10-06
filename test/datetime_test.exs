defmodule Typster.DatetimeTest do
  @moduledoc """
  Tests for Date, DateTime, and NaiveDateTime conversion to Typst datetime type.
  """

  use ExUnit.Case

  describe "Date conversion" do
    test "renders Date in template" do
      template = """
      = Date Test

      Date: #date

      Formatted: #date.display("[year]-[month]-[day]")
      """

      variables = %{
        date: ~D[2025-10-03]
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
      assert byte_size(pdf) > 1000
    end

    test "renders Date with custom formatting" do
      template = """
      = Invoice

      Date: #invoice_date.display("[month repr:long] [day], [year]")
      """

      variables = %{
        invoice_date: ~D[2025-12-25]
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
    end

    test "handles multiple Date values" do
      template = """
      = Date Range

      Start: #start_date.display("[year]-[month]-[day]")

      End: #end_date.display("[year]-[month]-[day]")
      """

      variables = %{
        start_date: ~D[2025-01-01],
        end_date: ~D[2025-12-31]
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
    end
  end

  describe "DateTime conversion" do
    test "renders DateTime in template" do
      {:ok, dt} = DateTime.new(~D[2025-10-03], ~T[14:30:00], "Etc/UTC")

      template = """
      = DateTime Test

      DateTime: #dt

      Formatted: #dt.display("[year]-[month]-[day] [hour]:[minute]:[second]")
      """

      variables = %{
        dt: dt
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
      assert byte_size(pdf) > 1000
    end

    test "renders DateTime with custom formatting" do
      {:ok, dt} = DateTime.new(~D[2025-03-15], ~T[09:45:30], "Etc/UTC")

      template = """
      = Report Generated

      Timestamp: #timestamp.display("[month repr:long] [day], [year] at [hour]:[minute] [period]")
      """

      variables = %{
        timestamp: dt
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
    end

    test "uses current datetime" do
      template = """
      = Current Time

      Generated: #created_at.display("[year]-[month]-[day] [hour]:[minute]")
      """

      variables = %{
        created_at: DateTime.utc_now()
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
    end
  end

  describe "NaiveDateTime conversion" do
    test "renders NaiveDateTime in template" do
      template = """
      = NaiveDateTime Test

      Time: #event_time

      Formatted: #event_time.display("[year]-[month]-[day] [hour]:[minute]")
      """

      variables = %{
        event_time: ~N[2025-10-03 14:30:00]
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
      assert byte_size(pdf) > 1000
    end

    test "handles multiple NaiveDateTime values" do
      template = """
      = Event Schedule

      Start: #start_time.display("[hour]:[minute] [period]")

      End: #end_time.display("[hour]:[minute] [period]")
      """

      variables = %{
        start_time: ~N[2025-10-03 09:00:00],
        end_time: ~N[2025-10-03 17:00:00]
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
    end
  end

  describe "mixed date/datetime usage" do
    test "combines Date and DateTime in same template" do
      {:ok, created} = DateTime.new(~D[2025-10-03], ~T[14:30:00], "Etc/UTC")

      template = """
      = Document

      Invoice Date: #invoice_date.display("[month repr:long] [day], [year]")

      Due Date: #due_date.display("[month repr:long] [day], [year]")

      Created: #created_at.display("[year]-[month]-[day] [hour]:[minute]:[second]")
      """

      variables = %{
        invoice_date: ~D[2025-10-03],
        due_date: ~D[2025-11-03],
        created_at: created
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
    end

    test "uses dates in variables and calculations" do
      template = """
      = Invoice

      #let invoice_date = date
      #let due_date = date

      Invoice Date: #invoice_date.display("[year]-[month]-[day]")

      Payment Terms: Net 30

      Due Date: #due_date.display("[year]-[month]-[day]")
      """

      variables = %{
        date: ~D[2025-10-03]
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
    end
  end

  describe "real-world use cases" do
    test "renders invoice with dates" do
      {:ok, created} = DateTime.new(~D[2025-10-03], ~T[14:30:00], "Etc/UTC")

      template = """
      = INVOICE

      *Invoice Number:* #invoice_number

      *Invoice Date:* #invoice_date.display("[month repr:long] [day], [year]")

      *Due Date:* #due_date.display("[month repr:long] [day], [year]")

      *Generated:* #generated_at.display("[year]-[month]-[day] [hour]:[minute]")

      ---

      *Amount Due:* \\$#amount

      Please remit payment by #due_date.display("[month]/[day]/[year]").
      """

      variables = %{
        invoice_number: "INV-2025-001",
        invoice_date: ~D[2025-10-03],
        due_date: ~D[2025-11-03],
        generated_at: created,
        amount: "1,234.56"
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
      assert byte_size(pdf) > 2000
    end

    test "renders contract with effective dates" do
      template = """
      = CONTRACT AGREEMENT

      This agreement, entered into on #effective_date.display("[month repr:long] [day], [year]"),
      between the parties listed below:

      *Effective Date:* #effective_date.display("[year]-[month]-[day]")

      *Expiration Date:* #expiration_date.display("[year]-[month]-[day]")

      *Last Modified:* #modified_at.display("[year]-[month]-[day] at [hour]:[minute]")

      The term of this agreement shall commence on the Effective Date and continue until
      the Expiration Date unless terminated earlier in accordance with the terms herein.
      """

      {:ok, modified} = DateTime.new(~D[2025-10-01], ~T[16:45:00], "Etc/UTC")

      variables = %{
        effective_date: ~D[2025-10-03],
        expiration_date: ~D[2026-10-03],
        modified_at: modified
      }

      assert {:ok, pdf} = Typster.render_pdf(template, variables)
      assert is_binary(pdf)
      assert byte_size(pdf) > 2000
    end
  end
end
